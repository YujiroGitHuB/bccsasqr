<?php
session_start();
include __DIR__ . '/../includes/permissions.php';
include __DIR__ . '/../includes/db_connect.php';

header('Content-Type: application/json');

requirePermissionJson('subjects.manage');

$code = trim($_POST['subject_code'] ?? '');
$name = trim($_POST['subject_name'] ?? '');

if ($code === '' || $name === '') {
    echo json_encode(["success" => false, "message" => "All fields are required"]);
    exit;
}

$check = $conn->prepare("SELECT id FROM subjects_tbl WHERE subject_code = ?");
$check->bind_param("s", $code);
$check->execute();
$check->store_result();

if ($check->num_rows > 0) {
    echo json_encode([
        "success" => false,
        "message" => "Subject code already exists!"
    ]);
    $check->close();
    exit;
}
$check->close();

$stmt = $conn->prepare("INSERT INTO subjects_tbl (subject_code, subject_name, created_at) VALUES (?, ?, NOW())");
$stmt->bind_param("ss", $code, $name);

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "Subject added successfully!"
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "Error adding subject"
    ]);
}
$stmt->close();
