<?php
session_start();
include "db_connect.php";
include "auth.php";
include "permissions.php";

// Ensure only admin can assign
if(!isAdmin()){
    echo json_encode(['success'=>false,'message'=>'Unauthorized']);
    exit;
}

if($_SERVER['REQUEST_METHOD'] === 'POST'){
    $section = trim($_POST['section']);
    $instructor_id = intval($_POST['instructor_id']);

    // Check if already assigned
    $check = mysqli_prepare($conn, "SELECT * FROM instructor_section_tbl WHERE instructor_id=? AND section=?");
    mysqli_stmt_bind_param($check, "is", $instructor_id, $section);
    mysqli_stmt_execute($check);
    $result = mysqli_stmt_get_result($check);

    if(mysqli_num_rows($result) > 0){
        echo json_encode(['success'=>false,'message'=>'This section is already assigned to this instructor.']);
        exit;
    }

    // Insert assignment
    $insert = mysqli_prepare($conn, "INSERT INTO instructor_section_tbl (instructor_id, section) VALUES (?, ?)");
    mysqli_stmt_bind_param($insert, "is", $instructor_id, $section);

    if(mysqli_stmt_execute($insert)){
        echo json_encode(['success'=>true,'message'=>'Section assigned successfully!']);
    } else {
        echo json_encode(['success'=>false,'message'=>'Error: '.mysqli_error($conn)]);
    }
}