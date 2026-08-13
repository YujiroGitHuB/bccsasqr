<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized access']);
    exit;
}

// Wiping the entire roster is kept admin-only rather than riding on
// students.delete — same call as crud/delete_all_attendance.php. An
// instructor granted students.delete can remove records, not the
// whole table. Before this, any signed-in user could empty it.
if (!isAdmin()) {
    echo json_encode(['success' => false, 'message' => 'Only an administrator can delete all students.']);
    exit;
}

// Delete all students
$sql = "DELETE FROM students_tbl";

if ($conn->query($sql) === TRUE) {
    $deleted_count = $conn->affected_rows;
    echo json_encode([
        'success' => true, 
        'message' => "Successfully deleted $deleted_count student(s)"
    ]);
} else {
    echo json_encode([
        'success' => false, 
        'message' => 'Error deleting students: ' . $conn->error
    ]);
}

$conn->close();
?>