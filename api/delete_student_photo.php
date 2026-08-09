<?php
// ============================================================
//  api/delete_student_photo.php
//  Admin only — removes a student's photo from DB + disk
// ============================================================
session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

if (!isAdmin()) {
    http_response_code(403);
    exit(json_encode(['success' => false, 'message' => 'Unauthorized.']));
}

$body       = json_decode(file_get_contents('php://input'), true);
$student_id = intval($body['student_id'] ?? 0);

if ($student_id <= 0) {
    exit(json_encode(['success' => false, 'message' => 'Invalid student ID.']));
}

// Get photo path from DB
$stmt = $conn->prepare("SELECT photo_path FROM student_photos WHERE s_id = ? LIMIT 1");
$stmt->bind_param("i", $student_id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$row) {
    exit(json_encode(['success' => false, 'message' => 'No photo found for this student.']));
}

// Delete file from disk
$filepath = $_SERVER['DOCUMENT_ROOT'] . '/bccsasqr/' . $row['photo_path'];
if (file_exists($filepath)) {
    @unlink($filepath);
}

// Delete from DB
$del = $conn->prepare("DELETE FROM student_photos WHERE s_id = ?");
$del->bind_param("i", $student_id);
$del->execute();
$del->close();

exit(json_encode(['success' => true, 'message' => 'Photo removed successfully.']));