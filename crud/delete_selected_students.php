<?php
session_start();
include "../includes/auth.php";
include "../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

// Was reachable by any signed-in user despite the page being admin-only.
requirePermissionJson('students.delete');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method.']);
    exit;
}

// Validate IDs
if (empty($_POST['ids']) || !is_array($_POST['ids'])) {
    echo json_encode(['success' => false, 'message' => 'No students selected.']);
    exit;
}

// Sanitize — ensure all IDs are integers
$ids = array_map('intval', $_POST['ids']);
$ids = array_filter($ids, fn($id) => $id > 0);

if (empty($ids)) {
    echo json_encode(['success' => false, 'message' => 'Invalid student IDs.']);
    exit;
}

// Build placeholders: ?,?,?
$placeholders = implode(',', array_fill(0, count($ids), '?'));
$types        = str_repeat('i', count($ids));

$stmt = $conn->prepare("DELETE FROM students_tbl WHERE id IN ($placeholders)");
$stmt->bind_param($types, ...$ids);

if ($stmt->execute()) {
    $deleted = $stmt->affected_rows;
    $stmt->close();
    echo json_encode([
        'success' => true,
        'message' => "$deleted student(s) successfully deleted."
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to delete students: ' . $stmt->error
    ]);
}