<?php
// ============================================================
// STUDENTS LIST — AJAX endpoint
//
// Why: students.php used to render every student as an HTML row. At
// 474 students that is 253 KB; at 1,762 (the size of the dev DB) it
// is 3.5 MB. The same data as JSON is 67 KB — roughly 74% lighter —
// and DataTables builds the DOM for the current page only.
//
// Deliberately NO cache: the roster changes on every add, edit,
// delete, or CSV import. A stale list is worse than one query.
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

// Katulad ng guard ng students.php — admin lang.
if (empty($_SESSION['user_id']) || !isAdmin()) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized', 'data' => []]);
    exit;
}

$result = $conn->query("
    SELECT s.id, s.student_no, s.fullname, s.course, s.section,
           u.name AS added_by_name
    FROM students_tbl s
    LEFT JOIN users u ON s.user_id = u.id
    ORDER BY s.course, s.section, s.fullname
");

$rows = [];
while ($row = $result->fetch_assoc()) {
    $rows[] = [
        'id'         => (int) $row['id'],
        'student_no' => $row['student_no'],
        'fullname'   => $row['fullname'],
        'course'     => $row['course'],
        'section'    => $row['section'],
        'added_by'   => $row['added_by_name'] ?? 'N/A',
    ];
}

echo json_encode(['success' => true, 'data' => $rows]);
