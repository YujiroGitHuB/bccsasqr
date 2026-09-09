<?php
// ============================================================
// Ang talaan, bilang dokumento.
//
// Katabi ito ng export_integrity_csv.php, at magkaiba ang trabaho
// nila. Ang CSV ay datos: buong device_id, buong fingerprint,
// walang hangganan, binubuksan sa Excel at sinusuri. Ito ay papel:
// may letterhead, may saklaw, may lagda, at may hangganan — dahil
// ang siyamnapung pahinang PDF ay hindi binabasa ninuman.
//
// Kaya rin pinuputol dito ang device_id sa unang walo at wala ang
// fingerprint: ang taong binibigyan mo nito ay hindi maghahambing
// ng tatlumpu't dalawang karakter sa isang papel.
//
// Ang page furniture ay pinagsasaluhan ng tatlong ibang export —
// tingnan ang includes/pdf_report.php.
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
requirePermission('links.manage', '../pages/dashboard.php');
include __DIR__ . "/../includes/systemConfig.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";
require_once __DIR__ . "/../includes/integrity_filters.php";
require __DIR__ . '/../includes/pdf_report.php';

date_default_timezone_set('Asia/Manila');

if (!isset($_SESSION['user_id'])) {
    header("Location: ../index.php");
    exit;
}

$user_id   = (int) $_SESSION['user_id'];
$is_admin  = (($_SESSION['role'] ?? '') === 'admin');
$user_name = $_SESSION['user_name'] ?? $_SESSION['name'] ?? 'Unknown';

// Ang hangganan ng papel. Ang buong listahan ay nasa CSV; ito ang
// bilang na kayang tingnan ng isang tao sa isang upuan, at
// sinasabi ng dokumento kapag may hindi kasama.
const ATI_PDF_ROWS = 300;

// ── Ang parehong salaan ng pahina at ng CSV ──────────────────
$f = integrity_filters($_GET, $is_admin, $user_id);

$days   = $f['days'];
$show   = $f['show'];
$class  = $f['class'];
$q      = $f['q'];
$device = $f['device'];

$hasReview = integrity_has_column($conn, 'reviewed_at');

/** Isang tanong sa audit, ligtas kahit wala pa ang talahanayan. */
function ati_pdf_query(mysqli $conn, string $sql, string $types, array $params): ?array
{
    try {
        $stmt = $conn->prepare($sql);
        if ($types !== '') $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        return $rows;
    } catch (Throwable $e) {
        error_log('export_integrity_pdf: ' . $e->getMessage());
        return null;
    }
}

// ── Mga bilang ───────────────────────────────────────────────
$totals = ati_pdf_query($conn, "
    SELECT
        SUM(a.result = 'ok')           AS ok,
        SUM(a.result = 'device_reuse') AS device_reuse,
        SUM(a.result = 'not_enrolled') AS not_enrolled,
        SUM(a.result = 'lookup_limit') AS lookup_limit,
        SUM(a.result = 'duplicate')    AS duplicate
    FROM attendance_audit_tbl a
    WHERE {$f['where']}
", $f['types'], $f['params']);

if ($totals === null) {
    header('Content-Type: text/plain; charset=utf-8');
    echo "The integrity log is not set up yet.\n"
       . "Run migrations/2026-09-09_add_attendance_integrity.sql against the database.";
    exit();
}

$t      = $totals[0] ?? [];
$nOk    = (int) ($t['ok']           ?? 0);
$nReuse = (int) ($t['device_reuse'] ?? 0);
$nUnenr = (int) ($t['not_enrolled'] ?? 0);
$nHunt  = (int) ($t['lookup_limit'] ?? 0);
$nDup   = (int) ($t['duplicate']    ?? 0);

// ── Mga device na nagsilbi sa mahigit isang estudyante ───────
$devices = ati_pdf_query($conn, "
    SELECT a.device_id,
           MAX(a.user_agent)              AS user_agent,
           MAX(a.ip)                      AS ip,
           COUNT(DISTINCT a.student_no)   AS students,
           SUM(a.result = 'ok')           AS saved,
           SUM(a.result = 'device_reuse') AS blocked,
           MAX(a.created_at)              AS last_seen,
           GROUP_CONCAT(DISTINCT a.student_no ORDER BY a.student_no SEPARATOR ', ') AS student_list
    FROM attendance_audit_tbl a
    WHERE {$f['where']}
      AND a.device_id IS NOT NULL
      AND a.result IN ('ok', 'device_reuse')
    GROUP BY a.device_id
    HAVING students > 1
    ORDER BY students DESC, last_seen DESC
    LIMIT 40
", $f['types'], $f['params']) ?? [];

// ── Ang mga hilera ───────────────────────────────────────────
$countRow = ati_pdf_query($conn, "
    SELECT COUNT(*) AS n FROM attendance_audit_tbl a WHERE {$f['all_where']}
", $f['all_types'], $f['all_params']);
$eventTotal = (int) ($countRow[0]['n'] ?? 0);

$events = ati_pdf_query($conn, "
    SELECT a.*, s.fullname
           " . ($hasReview ? ', ru.name AS reviewed_by_name' : '') . "
    FROM attendance_audit_tbl a
    LEFT JOIN students_tbl s ON s.student_no = a.student_no
    " . ($hasReview ? ' LEFT JOIN users ru ON ru.id = a.reviewed_by ' : '') . "
    WHERE {$f['all_where']}
    ORDER BY a.id DESC
    LIMIT " . ATI_PDF_ROWS . "
", $f['all_types'], $f['all_params']) ?? [];

/** Ang label ng bawat kahihinatnan — teksto lamang, walang ikon. */
function pdf_result_label(string $result): string
{
    switch ($result) {
        case 'ok':            return 'Saved';
        case 'device_reuse':  return 'Same device';
        case 'lookup_limit':  return 'Lookup limit';
        case 'not_enrolled':  return 'Not enrolled';
        case 'no_student':    return 'No such number';
        case 'bad_link':      return 'Link not valid';
        case 'save_failed':   return 'Save failed';
        case 'duplicate':     return 'Already in';
        case 'link_expired':  return 'Link had closed';
        case 'link_off':      return 'Link off';
        case 'form_locked':   return 'Form locked';
        case 'photo_missing': return 'No photo yet';
        default:              return ucfirst(str_replace('_', ' ', $result));
    }
}

/** Ang telepono, sa isang sulyap. Kapareho ng pahina. */
function pdf_device_label(?string $ua): string
{
    $ua = (string) $ua;
    if ($ua === '') return 'Unknown device';

    $os = 'Unknown';
    if (preg_match('/Android[ \/]?([\d.]+)?/i', $ua, $m))      $os = 'Android ' . ($m[1] ?? '');
    elseif (preg_match('/iPhone OS ([\d_]+)/i', $ua, $m))      $os = 'iPhone ' . str_replace('_', '.', $m[1]);
    elseif (stripos($ua, 'iPad') !== false)                    $os = 'iPad';
    elseif (stripos($ua, 'Windows') !== false)                 $os = 'Windows';
    elseif (stripos($ua, 'Mac OS X') !== false)                $os = 'Mac';
    elseif (stripos($ua, 'Linux') !== false)                   $os = 'Linux';

    $browser = 'Browser';
    if (stripos($ua, 'FBAV') !== false || stripos($ua, 'FB_IAB') !== false) $browser = 'Facebook';
    elseif (stripos($ua, 'Edg/') !== false)                                 $browser = 'Edge';
    elseif (stripos($ua, 'OPR/') !== false)                                 $browser = 'Opera';
    elseif (stripos($ua, 'Chrome') !== false)                               $browser = 'Chrome';
    elseif (stripos($ua, 'Firefox') !== false)                              $browser = 'Firefox';
    elseif (stripos($ua, 'Safari') !== false)                               $browser = 'Safari';

    return trim($os) . ' / ' . $browser;
}

// ── Ang dokumento ────────────────────────────────────────────
//
// Landscape: walong hanay ang isang hilera, at ang bawat isa ay
// kailangang mabasa. Sa portrait ay dalawa rito ang magiging
// tatlong karakter at isang tuldok.
$pdf = new ReportPDF('L', 'mm', 'A4');
$pdf->loadBranding($system);
$pdf->setReportTitle(
    'Attendance Integrity',
    'Submissions through the attendance link - ' . integrity_show_label($show)
);
$pdf->setPreparedBy($user_name);
$pdf->SetMargins(ReportPDF::MARGIN, 10, ReportPDF::MARGIN);
$pdf->SetAutoPageBreak(true, 20);
$pdf->AliasNbPages();
$pdf->AddPage();

$pdf->MetaBar([
    'Range'   => 'Last ' . $days . ' day' . ($days === 1 ? '' : 's'),
    'View'    => integrity_show_label($show),
    'Class'   => $class !== '' ? $class : 'All classes',
    'Search'  => $q !== '' ? $q : '-',
    'Device'  => $device !== '' ? $device : 'All devices',
    'Scope'   => $is_admin ? 'All instructors' : 'Own classes only',
], 3);

$pdf->StatCards([
    'Recorded'      => [number_format($nOk),    'plain'],
    'Same device'   => [number_format($nReuse), $nReuse > 0 ? 'bad'  : 'plain'],
    'Not enrolled'  => [number_format($nUnenr), $nUnenr > 0 ? 'warn' : 'plain'],
    'Looking around'=> [number_format($nHunt),  $nHunt  > 0 ? 'bad'  : 'plain'],
    'Repeats'       => [number_format($nDup),   'plain'],
]);

// Ang paalala tungkol sa saklaw. Nasa pahina rin ito, at mas
// kailangan pa rito: ang papel ay nawawalay sa screen na
// nagpapaliwanag nito.
$pdf->SetFont('Arial', 'I', 7.5);
$pdf->SetTextColor(120, 128, 138);
$pdf->MultiCell(0, 4, ReportPDF::txt(
    'Recorded counts submissions made through the attendance link only. Attendance taken with '
  . 'the QR scanner, or brought in by import, does not pass through this log and is not counted here. '
  . 'The log keeps the last 30 days.'
), 0, 'L');
$pdf->SetTextColor(0, 0, 0);
$pdf->Ln(3);

// ── Mga device na nagsilbi sa mahigit isang estudyante ───────
$pdf->BlockTitle('Devices used by more than one student');

$pdf->SetFont('Arial', 'I', 7.5);
$pdf->SetTextColor(120, 128, 138);
$pdf->MultiCell(0, 4, ReportPDF::txt(
    'One phone with two names on it may be a borrowed phone. One with five is not. '
  . 'Blocked counts the attempts that were turned away.'
), 0, 'L');
$pdf->SetTextColor(0, 0, 0);
$pdf->Ln(1);

// 60 + 20 + 97 + 25 + 25 + 50 = 277 = 297 - (10 * 2)
$pdf->setTableColumns([
    [60, 'Device',     'L'],
    [20, 'Students',   'C'],
    [97, 'Student numbers', 'L'],
    [25, 'Saved',      'C'],
    [25, 'Blocked',    'C'],
    [50, 'Last seen',  'C'],
]);
$pdf->TableHead();
$pdf->BeginTableBody();

if (empty($devices)) {
    $pdf->EmptyRow('Every device in this view submitted for one student only.');
} else {
    $pdf->SetFont('Arial', '', 8.5);
    $i = 0;
    foreach ($devices as $d) {
        $fill = ($i++ % 2) === 1;
        $pdf->SetFillColor(247, 249, 251);

        // Tatlo o higit pa sa isang telepono: pinapapula ang bilang,
        // at hindi ang buong hilera — ang teksto ang binabasa rito.
        $hot = (int) $d['students'] >= 3;

        $label = pdf_device_label($d['user_agent']) . '  ' . substr((string) $d['device_id'], 0, 8);

        $pdf->Cell(60, 7, $pdf->fit($label, 60), 1, 0, 'L', $fill);

        if ($hot) { $pdf->SetTextColor(185, 28, 28); $pdf->SetFont('Arial', 'B', 8.5); }
        $pdf->Cell(20, 7, (string) (int) $d['students'], 1, 0, 'C', $fill);
        if ($hot) { $pdf->SetTextColor(0, 0, 0); $pdf->SetFont('Arial', '', 8.5); }

        $pdf->Cell(97, 7, $pdf->fit((string) $d['student_list'], 97), 1, 0, 'L', $fill);
        $pdf->Cell(25, 7, (string) (int) $d['saved'],   1, 0, 'C', $fill);
        $pdf->Cell(25, 7, (string) (int) $d['blocked'], 1, 0, 'C', $fill);
        $pdf->Cell(50, 7, date('M j, Y g:i A', strtotime($d['last_seen'])), 1, 1, 'C', $fill);
    }
}

$pdf->EndTableBody();
$pdf->Ln(5);

// ── Ang mga hilera ───────────────────────────────────────────
$pdf->BlockTitle('Submissions - ' . integrity_show_label($show));

if ($eventTotal > count($events)) {
    // Ang pinutol na listahan ay dapat sabihing pinutol. Ang CSV ang
    // may buo — sinasabi rin niyan kung saan ito kukunin.
    $pdf->SetFont('Arial', 'I', 7.5);
    $pdf->SetTextColor(120, 128, 138);
    $pdf->MultiCell(0, 4, ReportPDF::txt(
        'Showing the ' . count($events) . ' most recent of ' . number_format($eventTotal)
      . '. Use the CSV export for the complete list.'
    ), 0, 'L');
    $pdf->SetTextColor(0, 0, 0);
    $pdf->Ln(1);
}

// Walang review: 32 + 24 + 60 + 48 + 40 + 20 + 26 + 27 = 277
// May review:   30 + 22 + 50 + 40 + 34 + 18 + 24 + 24 + 35 = 277
$cols = $hasReview
    ? [[30, 'When', 'C'], [22, 'Student no', 'C'], [50, 'Name', 'L'], [40, 'Class', 'L'],
       [34, 'Device', 'L'], [18, 'ID', 'C'], [24, 'IP', 'C'], [24, 'Result', 'C'], [35, 'Reviewed', 'L']]
    : [[32, 'When', 'C'], [24, 'Student no', 'C'], [60, 'Name', 'L'], [48, 'Class', 'L'],
       [40, 'Device', 'L'], [20, 'ID', 'C'], [26, 'IP', 'C'], [27, 'Result', 'C']];

$pdf->setTableColumns($cols);
$pdf->TableHead();
$pdf->BeginTableBody();

if (empty($events)) {
    $pdf->EmptyRow($show === 'flagged'
        ? 'Nothing was turned away in this view.'
        : 'Nothing recorded in this view.');
} else {
    $pdf->SetFont('Arial', '', 8);
    $i = 0;

    foreach ($events as $e) {
        $fill = ($i++ % 2) === 1;
        $pdf->SetFillColor(247, 249, 251);

        $result = (string) $e['result'];
        $hot    = in_array($result, ['device_reuse', 'lookup_limit'], true);

        $class_txt = trim(trim((string) $e['subject_name']) . ' - ' . trim((string) $e['section']), ' -');

        // Ang lapad ay galing sa $cols para hindi mahiwalay ang ulo
        // at ang katawan ng talahanayan kapag nabago ang isa.
        [$wWhen, $wNo, $wName, $wClass, $wDev, $wId, $wIp, $wRes] = array_column($cols, 0);

        $pdf->Cell($wWhen,  7, date('M j, g:i A', strtotime($e['created_at'])),          1, 0, 'C', $fill);
        $pdf->Cell($wNo,    7, $pdf->fit((string) $e['student_no'], $wNo),               1, 0, 'C', $fill);
        $pdf->Cell($wName,  7, $pdf->fit((string) ($e['fullname'] ?? ''), $wName),       1, 0, 'L', $fill);
        $pdf->Cell($wClass, 7, $pdf->fit($class_txt, $wClass),                           1, 0, 'L', $fill);
        $pdf->Cell($wDev,   7, $pdf->fit(pdf_device_label($e['user_agent']), $wDev),     1, 0, 'L', $fill);
        $pdf->Cell($wId,    7, substr((string) $e['device_id'], 0, 8),                   1, 0, 'C', $fill);
        $pdf->Cell($wIp,    7, $pdf->fit((string) $e['ip'], $wIp),                       1, 0, 'C', $fill);

        if ($hot) { $pdf->SetTextColor(185, 28, 28); $pdf->SetFont('Arial', 'B', 8); }
        $pdf->Cell($wRes, 7, $pdf->fit(pdf_result_label($result), $wRes), 1, $hasReview ? 0 : 1, 'C', $fill);
        if ($hot) { $pdf->SetTextColor(0, 0, 0); $pdf->SetFont('Arial', '', 8); }

        if ($hasReview) {
            // Ang tala ang binabasa, hindi ang petsa: iyon ang
            // dahilan kung bakit hindi na kailangang tingnan muli
            // ang hilerang ito.
            $wNote = $cols[8][0];
            $mark  = '';
            if (!empty($e['reviewed_at'])) {
                $mark = (string) ($e['note'] ?? '');
                if ($mark === '') $mark = 'Reviewed';
            }
            $pdf->Cell($wNote, 7, $pdf->fit($mark, $wNote), 1, 1, 'L', $fill);
        }
    }
}

$pdf->EndTableBody();
$pdf->AddSignature();

$stamp = date('Y-m-d_H-i');
$pdf->Output('I', 'attendance-integrity_' . $show . '_' . $days . 'd_' . $stamp . '.pdf');
