<?php
// ============================================================
// ATTENDANCE RECORDS — AJAX endpoint (server-side processing)
//
// Ang pahina ay dumaan sa tatlong yugto:
//
//   1. Lahat ng hilera bilang HTML. 1,476 bytes kada isa, 1.00 MB sa
//      710 — at ang `pageLength: 5` ay hindi kailanman naglimita ng
//      kinukuha, ITINATAGO lamang nito ang iba.
//
//   2. Lahat ng hilera bilang JSON. 127 KB — apat na beses na mas
//      magaan, pero LAHAT pa rin: ang ikapitong daang hilera ay
//      dumarating sa telepono kahit lima lang ang nakikita.
//
//   3. Ito. Ang hinihingi lamang ng nakabukas na pahina ang umaalis
//      ng database — dalawampu't lima, hindi pitong daan. Ang laki ng
//      sagot ay hindi na nakadepende sa dami ng records: pareho ang
//      bigat nito sa 700 at sa 70,000.
//
// Ang search, sort at ang section filter ay nasa SERVER na rin. Wala
// itong pagpipilian: hindi mahahanap ng browser ang hilerang hindi
// naman nito hawak. Iyon ang kapalit ng server-side processing, at
// iyon ang dahilan kung bakit dito nakasulat ang tatlo.
//
// Protokol: ang server-side na anyo ng DataTables 1.13 —
// tumatanggap ng draw/start/length/search/order, at nagsasauli ng
// draw, recordsTotal, recordsFiltered at data.
//
// Sinasadyang WALANG cache: nagbabago ang attendance sa bawat scan at
// sa bawat pagbura.
// ============================================================

ob_start();

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

ob_clean();
header('Content-Type: application/json');

$draw = (int) ($_GET['draw'] ?? 0);

/** Ang anyo ng pagkabigo na naiintindihan ng DataTables. */
$fail = function (string $msg) use ($draw) {
    echo json_encode([
        'draw'            => $draw,
        'recordsTotal'    => 0,
        'recordsFiltered' => 0,
        'data'            => [],
        'error'           => $msg,
    ]);
    exit;
};

if (empty($_SESSION['user_id'])) {
    $fail('Unauthorized');
}
if (!can('attendance.view')) {
    $fail('You do not have permission to view attendance.');
}

$user_id = (int) $_SESSION['user_id'];

// ── Ang bintana ng petsa ────────────────────────────────────
//
// Kaparehong-kapareho ng pagsusuri sa pages/attendance.php, at
// sinasadya: ang pahina ang nagpapakita ng From at To, pero ang
// endpoint na ito ang humahawak sa database. Kapag ang isa ay
// tumanggap ng halagang tinanggihan ng isa, ang makikita ng
// instruktor ay talahanayang hindi tumutugma sa mga petsang nakasulat
// sa itaas nito.
$DEFAULT_WINDOW_DAYS = 30;

$validDate = function ($v) {
    if (!is_string($v)) return null;
    $v = trim($v);
    $d = DateTime::createFromFormat('Y-m-d', $v);
    return ($d && $d->format('Y-m-d') === $v) ? $v : null;
};

$from = $validDate($_GET['from'] ?? null) ?? date('Y-m-d', strtotime("-{$DEFAULT_WINDOW_DAYS} days"));
$to   = $validDate($_GET['to']   ?? null) ?? date('Y-m-d');

if ($from > $to) {
    [$from, $to] = [$to, $from];
}

// ── Ang batayang hanay ──────────────────────────────────────
//
// Ang admin ay nakikita ang lahat; ang instructor ay ang sarili
// niyang naitala lamang. Ang WHERE at ang mga parameter nito ay
// binubuo nang isang beses at ginagamit ng tatlong tanong sa ibaba —
// ang bilang, ang salang bilang, at ang mga hilera. Kung maghihiwalay
// ang tatlo, magsasabi ang pahina ng bilang na hindi tumutugma sa
// nakikitang laman.
$where  = ['date BETWEEN ? AND ?'];
$types  = 'ss';
$params = [$from, $to];

if (!isAdmin()) {
    $where[]  = 'user_id = ?';
    $types   .= 'i';
    $params[] = $user_id;
}

// ── Kabuuan bago ang paghahanap ─────────────────────────────
$sqlWhere = 'WHERE ' . implode(' AND ', $where);

$totalStmt = $conn->prepare("SELECT COUNT(*) AS n FROM attendance_tbl $sqlWhere");
$totalStmt->bind_param($types, ...$params);
$totalStmt->execute();
$recordsTotal = (int) $totalStmt->get_result()->fetch_assoc()['n'];
$totalStmt->close();

// ── Ang section filter ──────────────────────────────────────
//
// Ang hanay na `section` ay minsang naka-imbak nang buo ("BSIT-2A")
// at minsang hubad ("2A") — nagbago ito sa paglipas ng panahon.
// Sinasalubong ang dalawa nang hindi ginagamitan ng function ang
// column, dahil ang REGEXP_REPLACE sa WHERE ay pumapatay sa bawat
// index na maaari sanang gamitin.
$section = trim((string) ($_GET['section'] ?? ''));

if ($section !== '') {
    $where[]  = "(section = ? OR section = CONCAT(course, '-', ?))";
    $types   .= 'ss';
    $params[] = $section;
    $params[] = $section;
}

// ── Ang paghahanap ──────────────────────────────────────────
//
// Ang kahon sa itaas ng talahanayan. Buong pagsusuri ito sa loob ng
// bintana ng petsa — walang index na tutulong sa LIKE '%x%' — pero
// ang bintanang iyon ang siyang naghahangganan nito, at hindi kailanman
// buong talaan ang nasusuri.
$search = trim((string) ($_GET['search']['value'] ?? ''));

if ($search !== '') {
    $where[] = '(student_no LIKE ? OR name LIKE ? OR course LIKE ? '
             . 'OR section LIKE ? OR subject LIKE ? OR date LIKE ?)';
    $like = '%' . $search . '%';
    for ($i = 0; $i < 6; $i++) {
        $types   .= 's';
        $params[] = $like;
    }
}

$sqlWhere = 'WHERE ' . implode(' AND ', $where);

$filtStmt = $conn->prepare("SELECT COUNT(*) AS n FROM attendance_tbl $sqlWhere");
$filtStmt->bind_param($types, ...$params);
$filtStmt->execute();
$recordsFiltered = (int) $filtStmt->get_result()->fetch_assoc()['n'];
$filtStmt->close();

// ── Ang pagkakasunod ────────────────────────────────────────
//
// Naka-whitelist ang mga hanay: ang index na galing sa browser ay
// tinutumbasan ng pangalang isinulat DITO, hindi kailanman idinidikit
// sa SQL. Ang hindi kilalang index ay bumabagsak sa petsa.
//
// Ang time_in ay VARCHAR na "09:11:58 AM", kaya ang pag-uri nito
// bilang teksto ay naglalagay ng 01:00 PM bago ang 09:00 AM. Iyon ang
// dating asal, at mali ito noon pa man — binabasa na ito ngayon bilang
// oras.
$columns = [
    2 => 'date',
    3 => 'student_no',
    4 => 'name',
    5 => 'course',
    6 => 'section',
    7 => "STR_TO_DATE(time_in, '%h:%i:%s %p')",
    8 => 'subject',
];

$orderCol = (int) ($_GET['order'][0]['column'] ?? 2);
$orderDir = strtolower((string) ($_GET['order'][0]['dir'] ?? 'desc')) === 'asc' ? 'ASC' : 'DESC';
$orderBy  = $columns[$orderCol] ?? 'date';

// Pangalawang susi ang id: ang mga hilerang iisa ang petsa ay walang
// tiyak na pagkakasunod kung wala ito, at ang parehong hilera ay
// maaaring lumabas sa dalawang magkaibang pahina — o hindi lumabas
// kahit saan.
$orderSql = "ORDER BY $orderBy $orderDir, id DESC";

// ── Ang pahina ──────────────────────────────────────────────
$start  = max(0, (int) ($_GET['start'] ?? 0));
$length = (int) ($_GET['length'] ?? 25);

// -1 ang ibig sabihin ng "All" sa dropdown. Hindi ito ipinagbabawal —
// pinili ito ng gumagamit — pero may hangganan pa rin: ang isang
// pahinang may 50,000 hilera ay hindi pagpipilian kundi nakabitin na
// browser.
$MAX_ROWS = 2000;
$limitSql = 'LIMIT ?, ?';
$limitLen = ($length < 1 || $length > $MAX_ROWS) ? $MAX_ROWS : $length;

$rowTypes  = $types . 'ii';
$rowParams = array_merge($params, [$start, $limitLen]);

$stmt = $conn->prepare("
    SELECT id, date, student_no, name, course, section, time_in, subject
    FROM attendance_tbl
    $sqlWhere
    $orderSql
    $limitSql
");
$stmt->bind_param($rowTypes, ...$rowParams);
$stmt->execute();
$result = $stmt->get_result();

$rows = [];
while ($row = $result->fetch_assoc()) {
    $rows[] = [
        'id'         => (int) $row['id'],
        'date'       => $row['date'],
        'student_no' => $row['student_no'],
        'name'       => $row['name'],
        'course'     => $row['course'],
        // Tinatanggal na rito ang unahang course ("BSIT-2A" → "2A"),
        // gaya ng dating ginagawa ng cleanSection() sa pahina.
        'section'    => preg_replace('/^[A-Z]+-/', '', (string) $row['section']),
        'time_in'    => $row['time_in'],
        'subject'    => $row['subject'],
    ];
}
$stmt->close();

echo json_encode([
    'draw'            => $draw,
    'recordsTotal'    => $recordsTotal,
    'recordsFiltered' => $recordsFiltered,
    'data'            => $rows,
]);
