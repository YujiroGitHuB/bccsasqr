<?php
// ============================================================
// ATTENDANCE SUMMARY — AJAX endpoint
//
// Why it is separate: this GROUP BY used to run on EVERY load of
// attendance.php, even with the Summary tab closed. Against a remote
// MySQL (sql108.infinityfree.com) that is an extra round trip per
// page view, and every row was rendered into the HTML as well. Now it
// only runs on request.
//
// The counting itself lives in includes/attendance_summary.php, which
// exports/export_summary_pdf.php calls as well — the tab and the PDF
// exported from it have to agree.
//
// Follows the pattern of get_links_ajax.php: JSON + a session cache
// with a TTL. Add ?refresh=1 to force fresh counts.
// ============================================================

ob_start();

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/attendance_summary.php";

ob_clean();
header('Content-Type: application/json');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$user_id = (int) $_SESSION['user_id'];

// Same as in attendance.php — "BSIT-2A" → "2A"
function cleanSection($section) {
    return preg_replace('/^[A-Z]+-/', '', $section);
}

// ─── Cache ────────────────────────────────────────────────────
// Shorter than attendance_links' 600s because the summary grows as
// attendance is taken. Five minutes is enough for a review screen.
//
// The key carries a version. A cached payload written before rows
// gained `sessions_held` would render as "3/" in the tab for up to
// five minutes after a deploy; bumping the version retires those
// instead of asking the front end to guess what an old row meant.
$cache_key = 'attendance_summary_v2_' . $user_id;
$cache_ttl = 300;

if (
    !isset($_GET['refresh']) &&
    isset($_SESSION[$cache_key]) &&
    (time() - $_SESSION[$cache_key]['time']) < $cache_ttl
) {
    $c = $_SESSION[$cache_key];
    echo json_encode([
        'success' => true,
        'cached'  => true,
        'data'    => $c['data'],
        'filters' => $c['filters'],
    ]);
    exit;
}

// ─── Fetch the summary ────────────────────────────────────────
$summaryData = attendance_summary_rows($conn, isAdmin(), $user_id);

// ─── Prepare the rows and the filters ─────────────────────────
$rows           = [];
$courses        = [];
$sectionsFilter = [];
$subjects       = [];

foreach ($summaryData as $row) {
    $cleanSec = cleanSection($row['section']);

    if (!in_array($row['course'], $courses, true))      $courses[]        = $row['course'];
    if (!in_array($cleanSec, $sectionsFilter, true))    $sectionsFilter[] = $cleanSec;
    if ($row['subject'] && !in_array($row['subject'], $subjects, true)) {
        $subjects[] = $row['subject'];
    }

    $rows[] = [
        'student_no'    => $row['student_no'],
        'fullname'      => $row['fullname'],
        'course'        => $row['course'],
        'section'       => $cleanSec,
        'subject'       => $row['subject'] ?? 'N/A',
        'attended'      => $row['attended'],
        'sessions_held' => $row['sessions_held'],
        'first_seen'    => $row['first_seen'],
    ];
}

$filters = [
    'courses'  => $courses,
    'sections' => $sectionsFilter,
    'subjects' => $subjects,
];

$_SESSION[$cache_key] = [
    'time'    => time(),
    'data'    => $rows,
    'filters' => $filters,
];

echo json_encode([
    'success' => true,
    'cached'  => false,
    'data'    => $rows,
    'filters' => $filters,
]);
