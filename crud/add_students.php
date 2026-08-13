<?php
session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json'); // ensure clean JSON response

requirePermissionJson('students.manage', 'status');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $student_no = trim($_POST['student_no']);
    $fullname   = trim($_POST['fullname']);
    $course     = trim($_POST['course']);
    $section    = trim($_POST['section']);
    $user_id    = $_SESSION['user_id'] ?? null; // currently logged in user

    // Basic validation
    if (empty($student_no) || empty($fullname) || empty($course) || empty($section) || empty($user_id)) {
        echo json_encode(['status' => 'incomplete']);
        exit;
    }

    // Check for duplicates (same student number for this user)
    $check = $conn->prepare("SELECT id FROM students_tbl WHERE student_no = ?");
    $check->bind_param("s", $student_no);

    $check->execute();
    $check->store_result();

    if ($check->num_rows > 0) {
        echo json_encode(['status' => 'duplicate']);
        $check->close();
        exit;
    }
    $check->close();

    // Insert record
    $stmt = $conn->prepare("INSERT INTO students_tbl (student_no, fullname, course, section, user_id) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("ssssi", $student_no, $fullname, $course, $section, $user_id);

    if ($stmt->execute()) {
        echo json_encode(['status' => 'success']);
    } else {
        echo json_encode(['status' => 'error']);
    }

    $stmt->close();
}
