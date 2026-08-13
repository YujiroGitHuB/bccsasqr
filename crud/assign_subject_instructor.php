<?php
session_start();
include __DIR__ . '/../includes/permissions.php';
include __DIR__ . '/../includes/db_connect.php';

header('Content-Type: application/json');

requirePermissionJson('instructors.assign');

$subject    = intval($_POST['subject_id'] ?? 0);
$instructor = intval($_POST['instructor_id'] ?? 0);

if ($subject <= 0 || $instructor <= 0) {
    echo json_encode(["success" => false, "message" => "Invalid subject or instructor"]);
    exit;
}

$check = $conn->prepare("SELECT id FROM subject_instructors_tbl WHERE subject_id = ? AND instructor_id = ?");
$check->bind_param("ii", $subject, $instructor);
$check->execute();
$check->store_result();

if ($check->num_rows > 0) {
    echo json_encode([
        "success" => false,
        "message" => "Instructor already assigned."
    ]);
    $check->close();
    exit;
}
$check->close();

$stmt = $conn->prepare("INSERT INTO subject_instructors_tbl (subject_id, instructor_id) VALUES (?, ?)");
$stmt->bind_param("ii", $subject, $instructor);

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "Instructor assigned successfully!"
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "Error assigning instructor"
    ]);
}
$stmt->close();
