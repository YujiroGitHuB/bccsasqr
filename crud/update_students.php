<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id         = intval($_POST['id']);
    $student_no = trim($_POST['student_no']);
    $fullname   = trim($_POST['fullname']);
    $course     = trim($_POST['course']);
    $section    = trim($_POST['section']);
    $user_id    = $_SESSION['user_id'] ?? null;

    if (empty($id) || empty($student_no) || empty($fullname) || empty($course) || empty($section) || empty($user_id)) {
        echo json_encode(['status' => 'incomplete']);
        exit;
    }

    // Check if new student number already exists (except current one)
   $check = $conn->prepare("SELECT id FROM students_tbl WHERE student_no = ? AND id != ?");
$check->bind_param("si", $student_no, $id);

    $check->execute();
    $check->store_result();

    if ($check->num_rows > 0) {
        echo json_encode(['status' => 'duplicate']);
        $check->close();
        exit;
    }
    $check->close();

    // Update student record
   $stmt = $conn->prepare("UPDATE students_tbl SET student_no = ?, fullname = ?, course = ?, section = ? WHERE id = ?");
$stmt->bind_param("ssssi", $student_no, $fullname, $course, $section, $id);

    if ($stmt->execute()) {
        echo json_encode(['status' => 'success']);
    } else {
        echo json_encode(['status' => 'error']);
    }

    $stmt->close();
}
?>
