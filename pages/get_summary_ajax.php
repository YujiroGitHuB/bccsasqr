<?php
// ============================================================
// ATTENDANCE SUMMARY — AJAX endpoint
//
// Bakit hiwalay: dati ay tumatakbo ang GROUP BY na ito sa BAWAT
// pag-load ng attendance.php, kahit hindi binubuksan ang Summary
// tab. Sa remote MySQL (sql108.infinityfree.com) ay dagdag na
// round trip iyon kada page view, at ini-render pa ang lahat ng
// row sa HTML. Ngayon ay kapag hiniling na lang.
//
// Sinusundan ang pattern ng get_links_ajax.php: JSON + session
// cache na may TTL. Idagdag ang ?refresh=1 para pilitin ang
// sariwang bilang.
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

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$user_id = (int) $_SESSION['user_id'];

// Katulad ng nasa attendance.php — "BSIT-2A" → "2A"
function cleanSection($section) {
    return preg_replace('/^[A-Z]+-/', '', $section);
}

// ─── Cache ────────────────────────────────────────────────────
// Mas maikli kaysa sa 600s ng attendance_links dahil dumadagdag
// ang summary habang nag-a-attendance. Sapat ang 5 minuto para
// sa isang review screen.
$cache_key = 'attendance_summary_' . $user_id;
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

// ─── Kunin ang summary ────────────────────────────────────────
$summaryData = [];

if (isAdmin()) {
    $summaryResult = $conn->query("
        SELECT s.student_no, s.fullname, s.course, s.section,
               a.subject,
               COUNT(a.id) AS total_attendance
        FROM students_tbl s
        LEFT JOIN attendance_tbl a ON s.student_no = a.student_no
        GROUP BY s.student_no, s.fullname, s.course, s.section, a.subject
        ORDER BY s.fullname ASC, a.subject ASC
    ");
    if ($summaryResult) {
        while ($row = $summaryResult->fetch_assoc()) {
            $summaryData[] = $row;
        }
    }
} else {
    $secStmt = $conn->prepare("
        SELECT course, section
        FROM instructor_section_tbl
        WHERE instructor_id = ?
    ");
    $secStmt->bind_param("i", $user_id);
    $secStmt->execute();
    $secResult = $secStmt->get_result();

    $assigned = [];
    while ($row = $secResult->fetch_assoc()) {
        $assigned[] = $row;
    }

    if (!empty($assigned)) {
        $conditions = implode(' OR ', array_map(
            fn($s) => "(s.course = '" . $conn->real_escape_string($s['course']) . "'"
                    . " AND s.section = '" . $conn->real_escape_string($s['section']) . "')",
            $assigned
        ));

        $summaryResult = $conn->query("
            SELECT s.student_no, s.fullname, s.course, s.section,
                   a.subject,
                   COUNT(a.id) AS total_attendance
            FROM students_tbl s
            LEFT JOIN attendance_tbl a
                ON s.student_no = a.student_no
                AND a.user_id = $user_id
            WHERE $conditions
            GROUP BY s.student_no, s.fullname, s.course, s.section, a.subject
            ORDER BY s.fullname ASC, a.subject ASC
        ");
        if ($summaryResult) {
            while ($row = $summaryResult->fetch_assoc()) {
                $summaryData[] = $row;
            }
        }
    }
}

// ─── Ihanda ang rows at ang mga filter ────────────────────────
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
        'student_no'       => $row['student_no'],
        'fullname'         => $row['fullname'],
        'course'           => $row['course'],
        'section'          => $cleanSec,
        'subject'          => $row['subject'] ?? 'N/A',
        'total_attendance' => (int) $row['total_attendance'],
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
