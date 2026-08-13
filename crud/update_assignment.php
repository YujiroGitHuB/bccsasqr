<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

requirePermissionJson('instructors.assign');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $assignmentId = mysqli_real_escape_string($conn, $_POST['assignment_id']);
    $subjectId = mysqli_real_escape_string($conn, $_POST['subject_id']);
    $instructorId = mysqli_real_escape_string($conn, $_POST['instructor_id']);
    
    // Validate input
    if (empty($subjectId) || empty($instructorId)) {
        echo json_encode(['success' => false, 'message' => 'All fields are required']);
        exit;
    }
    
    // Check if this assignment already exists (excluding current assignment)
    $checkQuery = mysqli_query($conn, "SELECT * FROM subject_instructors_tbl WHERE subject_id = '$subjectId' AND instructor_id = '$instructorId' AND id != '$assignmentId'");
    
    if (mysqli_num_rows($checkQuery) > 0) {
        echo json_encode(['success' => false, 'message' => 'This instructor is already assigned to this subject']);
        exit;
    }
    
    // Update the assignment
    $updateQuery = mysqli_query($conn, "UPDATE subject_instructors_tbl SET subject_id = '$subjectId', instructor_id = '$instructorId' WHERE id = '$assignmentId'");
    
    if ($updateQuery) {
        echo json_encode(['success' => true, 'message' => 'Assignment updated successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to update assignment: ' . mysqli_error($conn)]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
}
?>