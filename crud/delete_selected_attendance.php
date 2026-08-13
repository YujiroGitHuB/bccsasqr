<?php
session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

// Require a logged-in user (instructor or admin).
if (empty($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

requirePermissionJson('attendance.delete');

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || empty($_POST['ids']) || !is_array($_POST['ids'])) {
    echo json_encode(['success' => false, 'message' => 'No records selected.']);
    exit;
}

// Sanitize — keep only positive integers.
$ids = array_values(array_filter(array_map('intval', $_POST['ids']), fn($id) => $id > 0));
if (empty($ids)) {
    echo json_encode(['success' => false, 'message' => 'Invalid record IDs.']);
    exit;
}

$placeholders = implode(',', array_fill(0, count($ids), '?'));
$types        = str_repeat('i', count($ids));

if (isAdmin()) {
    // Admins may delete any record.
    $stmt = $conn->prepare("DELETE FROM attendance_tbl WHERE id IN ($placeholders)");
    $stmt->bind_param($types, ...$ids);
} else {
    // Instructors may only delete their OWN records.
    $uid    = (int) $_SESSION['user_id'];
    $stmt   = $conn->prepare("DELETE FROM attendance_tbl WHERE id IN ($placeholders) AND user_id = ?");
    $params = array_merge($ids, [$uid]);
    $stmt->bind_param($types . 'i', ...$params);
}

if ($stmt->execute()) {
    echo json_encode(['success' => true, 'rows_deleted' => $stmt->affected_rows]);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to delete selected records.']);
}
$stmt->close();
