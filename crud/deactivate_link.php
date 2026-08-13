<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

if (!isset($_SESSION['user_id']) || !isset($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit();
}

requirePermissionJson('links.manage');

if (!isset($_POST['short_code'])) {
    echo json_encode(['success' => false, 'message' => 'Short code required']);
    exit();
}

$short_code = trim($_POST['short_code']);

$stmt = $conn->prepare("UPDATE attendance_links_tbl SET is_active = 0 WHERE short_code = ?");
$stmt->bind_param("s", $short_code);

if ($stmt->execute()) {
    echo json_encode(['success' => true]);
} else {
    echo json_encode(['success' => false, 'message' => 'Database error']);
}

$conn->close();
?>