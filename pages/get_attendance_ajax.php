<?php
// ============================================================
// ATTENDANCE RECORDS — AJAX endpoint
//
// Bakit: ang attendance.php ang huling talahanayang naglalabas ng
// buong laman nito bilang HTML. Ang `pageLength: 5` ng DataTables ay
// hindi naglilimita ng kinukuha — ITINATAGO lamang nito ang iba,
// nasa pahina pa rin silang lahat. Kaya ang "Showing 1 to 5" ay
// panlinlang: 710 na hilera ang dumarating sa telepono, hindi lima.
//
// Sinukat: 1,476 bytes ng HTML kada hilera — 1.00 MB sa 710 hilera.
// Ang parehong datos bilang JSON ay wala pang isang-sampu niyon.
// Sa hosting na naghahatid ng 60–120 KB kada segundo, ang pagkakaiba
// ay pito hanggang labingwalong segundo ng pagtitig sa "Please wait".
//
// Ang mga hangganan ng petsa ay galing pa rin sa From/To ng pahina at
// ipinapasa rito: ang hindi kinukuhang hilera ay hindi lamang
// itinatago — hindi ito umaalis ng database kahit kailan.
//
// Sinasadyang WALANG cache: nagbabago ang attendance sa bawat scan at
// sa bawat pagbura. Mas masama ang lumang listahan kaysa sa isang
// tanong.
//
// Kapareho ng anyo ng pages/get_students_ajax.php, ang unang
// talahanayang dumaan dito.
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

if (empty($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized', 'data' => []]);
    exit;
}
requirePermissionJson('attendance.view');

$user_id = (int) $_SESSION['user_id'];

// ── Ang bintana ng petsa ────────────────────────────────────
//
// Kaparehong-kapareho ng pagsusuri sa pages/attendance.php, at
// sinasadya: ang pahina ang nagpapakita ng From at To, pero ang
// endpoint na ito ang humahawak sa database. Kapag ang isa ay
// tumanggap ng halagang tinanggihan ng isa, ang makikita ng
// instruktor ay isang talahanayang hindi tumutugma sa mga petsang
// nakasulat sa itaas nito.
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

// ── Ang mga hilera ──────────────────────────────────────────
//
// Ang admin ay nakikita ang lahat; ang instructor ay ang sarili
// niyang naitala lamang — parehong hati ng pages/attendance.php.
if (isAdmin()) {
    $stmt = $conn->prepare("
        SELECT id, date, student_no, name, course, section, time_in, subject
        FROM attendance_tbl
        WHERE date BETWEEN ? AND ?
        ORDER BY date DESC
    ");
    $stmt->bind_param("ss", $from, $to);
} else {
    $stmt = $conn->prepare("
        SELECT id, date, student_no, name, course, section, time_in, subject
        FROM attendance_tbl
        WHERE user_id = ?
          AND date BETWEEN ? AND ?
        ORDER BY date DESC
    ");
    $stmt->bind_param("iss", $user_id, $from, $to);
}

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
        // gaya ng ginagawa ng cleanSection() sa pahina. Sa server ito
        // ginagawa at hindi sa browser: ang section filter ay
        // naghahambing ng eksaktong teksto, at ang dalawang magkaibang
        // anyo ng iisang section ay dalawang magkaibang pagpipilian sa
        // dropdown.
        'section'    => preg_replace('/^[A-Z]+-/', '', (string) $row['section']),
        'time_in'    => $row['time_in'],
        'subject'    => $row['subject'],
    ];
}
$stmt->close();

echo json_encode(['success' => true, 'data' => $rows]);
