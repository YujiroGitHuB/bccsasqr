<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

requirePermissionJson('sections.assign');

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['assignment_id'])) {
    $assignmentId = mysqli_real_escape_string($conn, $_POST['assignment_id']);
    
    // First, check if assignment exists
    $checkQuery = mysqli_query($conn, "SELECT * FROM instructor_section_tbl WHERE id = '$assignmentId'");
    
    if (mysqli_num_rows($checkQuery) == 0) {
        echo json_encode(['success' => false, 'message' => 'Assignment not found']);
        exit;
    }
    
    // Delete the assignment
    $deleteQuery = mysqli_query($conn, "DELETE FROM instructor_section_tbl WHERE id = '$assignmentId'");
    
    if ($deleteQuery) {
        echo json_encode(['success' => true, 'message' => 'Section assignment deleted successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to delete assignment: ' . mysqli_error($conn)]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
}
?>