<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized access']);
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