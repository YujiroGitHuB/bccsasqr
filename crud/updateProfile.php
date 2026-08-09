<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include __DIR__ . "/../includes/db_connect.php";
header("Content-Type: application/json");

$userId = $_SESSION['user_id'] ?? 0;

if (!$userId) {
    echo json_encode(["status" => "error", "message" => "Unauthorized."]);
    exit;
}

$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$password = trim($_POST['password'] ?? '');

if ($name === '' || $email === '') {
    echo json_encode(["status" => "warning", "message" => "Name and email cannot be empty."]);
    exit;
}

if (!empty($password)) {
    $hash = password_hash($password, PASSWORD_ARGON2ID);
    $stmt = $conn->prepare("UPDATE users SET name = ?, email = ?, password = ? WHERE id = ?");
    $stmt->bind_param("sssi", $name, $email, $hash, $userId);
} else {
    $stmt = $conn->prepare("UPDATE users SET name = ?, email = ? WHERE id = ?");
    $stmt->bind_param("ssi", $name, $email, $userId);
}

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Profile updated successfully!"]);
} else {
    echo json_encode(["status" => "error", "message" => "Update failed."]);
}
$stmt->close();
