<?php
// ============================================================
// Ang talaan, bilang file.
//
// Ang natuklasan sa pages/attendance_integrity.php ay madalas
// hindi nagtatapos sa pahinang iyon: dinadala ito sa estudyante,
// sa program head, minsan sa dean. Ang screenshot ng talahanayan ay
// hindi ebidensya — walang oras, walang saklaw, at walang makikita
// sa ilalim ng gilid ng screen.
//
// CSV at hindi PDF, hindi tulad ng tatlong export sa tabi nito:
// ang mga iyon ay talaan ng pagpasok na binabasa at pinipirmahan.
// Ito ay datos na sinasala at sinusuri — bubuksan ito sa Excel,
// isa-sort ayon sa device, at bibilangin. Ang PDF ay tumatanggi sa
// dalawang bagay na iyon.
//
// Kaparehong salaan at KAPAREHONG hangganan ng pahina: ang
// instruktor ay ang sarili niyang klase lamang. Kung nakalimutan
// ito rito, ang export ang magiging butas na isinara ng pahina.
// ============================================================

session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

// '../pages/dashboard.php' at hindi ang default na 'dashboard.php':
// nasa exports/ ang file na ito, kaya ang default ay magtuturo sa
// isang bagay na wala rito. Ganoon din ang ginagawa ng tatlong
// export sa tabi nito.
requirePermission('links.manage', '../pages/dashboard.php');
date_default_timezone_set('Asia/Manila');

$user_id  = (int) $_SESSION['user_id'];
$is_admin = ($_SESSION['role'] === 'admin');

// ── Ang parehong salaan ng pahina ────────────────────────────
$days = (int) ($_GET['days'] ?? 7);
if (!in_array($days, [1, 7, 30], true)) $days = 7;

$show = $_GET['show'] ?? 'flagged';
if (!in_array($show, ['flagged', 'all', 'ok', 'device_reuse', 'duplicate', 'not_enrolled', 'lookup_limit'], true)) {
    $show = 'flagged';
}

$class  = substr(trim((string) ($_GET['class'] ?? '')), 0, 10);
$q      = substr(trim((string) ($_GET['q'] ?? '')), 0, 60);
$device = (string) ($_GET['device'] ?? '');
if (!preg_match('/^[0-9a-f]{1,32}$/', $device)) $device = '';

$where  = ' a.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY) ';
$types  = 'i';
$params = [$days];

if (!$is_admin) {
    $where .= ' AND a.instructor_id = ? ';
    $types .= 'i';
    $params[] = $user_id;
}

if ($class !== '') {
    $where .= ' AND a.short_code = ? ';
    $types .= 's';
    $params[] = $class;
}

if ($device !== '') {
    $where .= ' AND a.device_id LIKE ? ';
    $types .= 's';
    $params[] = $device . '%';
}

if ($q !== '') {
    $where .= ' AND (a.student_no LIKE ?
                     OR EXISTS (SELECT 1 FROM students_tbl sq
                                WHERE sq.student_no = a.student_no
                                  AND sq.fullname LIKE ?)) ';
    $types .= 'ss';
    $params[] = '%' . $q . '%';
    $params[] = '%' . $q . '%';
}

if ($show === 'flagged') {
    $where .= " AND a.result IN ('device_reuse', 'not_enrolled', 'lookup_limit', 'no_student', 'bad_link') ";
} elseif ($show !== 'all') {
    $where .= ' AND a.result = ? ';
    $types .= 's';
    $params[] = $show;
}

// Walang LIMIT dito, hindi tulad ng pahina: ang pinutol na
// ebidensya ay hindi ebidensya. Ang talaan ay tatlumpung araw
// lamang ang laman, kaya may hangganan pa rin ito.
//
// May review columns ba? Ang export ay dapat gumana kahit hindi pa
// napapatakbo ang 2026-09-10_add_audit_review.sql — ang tanging
// mawawala ay tatlong hanay.
$hasReview = false;
try {
    $chk = $conn->query("
        SELECT COUNT(*) AS n FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name   = 'attendance_audit_tbl'
          AND column_name  = 'reviewed_at'
    ");
    $hasReview = $chk && ((int) $chk->fetch_assoc()['n'] > 0);
} catch (Throwable $e) {
    error_log('export_integrity_csv: ' . $e->getMessage());
}

$reviewCols = $hasReview
    ? ', a.reviewed_at, a.note, ru.name AS reviewed_by_name'
    : '';
$reviewJoin = $hasReview
    ? ' LEFT JOIN users ru ON ru.id = a.reviewed_by '
    : '';

$rows = [];
$failed = false;

try {
    $stmt = $conn->prepare("
        SELECT a.created_at, a.student_no, s.fullname, a.subject_name, a.section,
               a.short_code, a.device_id, a.fingerprint, a.ip, a.user_agent, a.result
               $reviewCols
        FROM attendance_audit_tbl a
        LEFT JOIN students_tbl s ON s.student_no = a.student_no
        $reviewJoin
        WHERE $where
        ORDER BY a.id DESC
    ");
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
} catch (Throwable $e) {
    error_log('export_integrity_csv: ' . $e->getMessage());
    $failed = true;
}

if ($failed) {
    header('Content-Type: text/plain; charset=utf-8');
    echo "The integrity log is not set up yet.\n"
       . "Run migrations/2026-09-09_add_attendance_integrity.sql against the database.";
    exit();
}

// ── Ang file ─────────────────────────────────────────────────
$stamp = date('Y-m-d_H-i');
$name  = 'attendance-integrity_' . $show . '_' . $days . 'd_' . $stamp . '.csv';

header('Content-Type: text/csv; charset=utf-8');
header('Content-Disposition: attachment; filename="' . $name . '"');
header('Cache-Control: no-store');

$out = fopen('php://output', 'w');

// BOM: kung wala ito ay binabasa ng Excel sa Windows ang UTF-8
// bilang ANSI, at ang bawat "ñ" sa pangalan ay nagiging dalawang
// karakter na basura sa isang dokumentong dadalhin sa isang tao.
fwrite($out, "\xEF\xBB\xBF");

// Dalawang linya ng konteksto bago ang mga hanay. Ang CSV na
// walang saklaw ay isang listahang walang masasabi kung ano ang
// hindi kasama rito.
fputcsv($out, ['BCC SASQR — Attendance Integrity']);
fputcsv($out, [
    'Exported',   date('M j, Y g:i A'),
    'Range',      'last ' . $days . ' day' . ($days === 1 ? '' : 's'),
    'Filter',     $show,
    'Class',      $class !== '' ? $class : 'all',
    'Search',     $q !== '' ? $q : '—',
    'Device',     $device !== '' ? $device : 'all',
    'Rows',       count($rows),
    'Scope',      $is_admin ? 'all instructors' : 'own classes only',
]);
fputcsv($out, []);

$head = ['When', 'Student no', 'Name', 'Subject', 'Section', 'Link code',
         'Device id', 'Fingerprint', 'IP', 'Device', 'Browser', 'Result'];
if ($hasReview) $head = array_merge($head, ['Reviewed at', 'Reviewed by', 'Note']);
fputcsv($out, $head);

/**
 * Isang cell na hindi magiging formula sa Excel.
 *
 * Ang student_no ay galing sa POST ng attendance form at hindi
 * kailanman sinuri — ang mga hilerang 'no_student' ay MISMONG ang
 * mga halagang hindi umiiral, kung ano man ang tinipa ng nagpadala.
 * Ang cell na nagsisimula sa "=" ay pinapatakbo ng Excel kapag
 * binuksan, at ang file na ito ay ginawa para ipadala sa ibang tao.
 *
 * Isang kudlit sa unahan: nawawala ito sa pagpapakita, at ang cell
 * ay nananatiling teksto.
 */
function csv_safe(?string $v): string
{
    $v = (string) $v;
    return (isset($v[0]) && strpos("=+-@\t\r", $v[0]) !== false) ? "'" . $v : $v;
}

/** Ang OS at browser, hiwalay — para masala sa Excel. */
function ua_parts(?string $ua): array
{
    $ua = (string) $ua;
    if ($ua === '') return ['Unknown', 'Unknown'];

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

    return [trim($os), $browser];
}

foreach ($rows as $r) {
    [$os, $browser] = ua_parts($r['user_agent'] ?? '');

    // Buong device_id dito at hindi ang unang walo: ang pahina ay
    // pinuputol ito para mabasa, ngunit ang file ay pinagsasama-sama
    // at inihahambing — at ang walong karakter ay maaaring magkatugma
    // nang aksidente.
    $line = [
        date('Y-m-d H:i:s', strtotime((string) $r['created_at'])),
        csv_safe($r['student_no']),
        csv_safe($r['fullname'] ?? ''),
        csv_safe($r['subject_name'] ?? ''),
        csv_safe($r['section'] ?? ''),
        csv_safe($r['short_code']),
        csv_safe($r['device_id'] ?? ''),
        csv_safe($r['fingerprint'] ?? ''),
        csv_safe($r['ip'] ?? ''),
        $os,
        $browser,
        csv_safe($r['result']),
    ];

    if ($hasReview) {
        $line[] = $r['reviewed_at'] ? date('Y-m-d H:i:s', strtotime((string) $r['reviewed_at'])) : '';
        $line[] = csv_safe($r['reviewed_by_name'] ?? '');
        $line[] = csv_safe($r['note'] ?? '');
    }

    fputcsv($out, $line);
}

fclose($out);
