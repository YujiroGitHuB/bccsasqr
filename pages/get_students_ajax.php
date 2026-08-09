<?php
// ============================================================
// STUDENTS LIST — AJAX endpoint
//
// Bakit: dating ini-render ng students.php ang bawat estudyante
// bilang HTML row. Sa 474 na estudyante ay 253 KB iyon; sa 1,762
// (laki ng dev DB) ay 3.5 MB. Ang parehong data bilang JSON ay
// 67 KB — humigit-kumulang 74% na mas magaan — at DataTables na
// ang bahalang gumawa ng DOM para sa kasalukuyang page lang.
//
// Sinadyang WALANG cache: nagbabago ang roster tuwing may add,
// edit, delete, o CSV import. Mas masama ang lumang listahan
// kaysa sa isang query.
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
