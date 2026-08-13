<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

requirePermissionJson('subjects.manage');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $subjectId = mysqli_real_escape_string($conn, $_POST['subject_id']);
    $subjectCode = mysqli_real_escape_string($conn, $_POST['subject_code']);
    $subjectName = mysqli_real_escape_string($conn, $_POST['subject_name']);
    
    // Validate input
    if (empty($subjectCode) || empty($subjectName)) {
        echo json_encode(['success' => false, 'message' => 'All fields are required']);
        exit;
    }
    
    // Check if subject code already exists (excluding current subject)
    $checkQuery = mysqli_query($conn, "SELECT * FROM subjects_tbl WHERE subject_code = '$subjectCode' AND id != '$subjectId'");
    
    if (mysqli_num_rows($checkQuery) > 0) {
        echo json_encode(['success' => false, 'message' => 'Subject code already exists']);
        exit;
    }
    
    // Update the subject
    $updateQuery = mysqli_query($conn, "UPDATE subjects_tbl SET subject_code = '$subjectCode', subject_name = '$subjectName' WHERE id = '$subjectId'");
    
    if ($updateQuery) {
        echo json_encode(['success' => true, 'message' => 'Subject updated successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to update subject: ' . mysqli_error($conn)]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
}
?>