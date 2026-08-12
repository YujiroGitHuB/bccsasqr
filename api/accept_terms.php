<?php
// ============================================================
// Records a student's acceptance of the Terms and Conditions before
// they can generate a QR.
//
// This is public, like the QR generator itself (students do not log
// in), so:
//   - only a student_no that actually exists in students_tbl is
//     accepted
//   - the version comes from the server, not the client — nobody can
//     force a different one
// ============================================================

include __DIR__ . '/../includes/db_connect.php';
require_once __DIR__ . '/../includes/terms.php';

header('Content-Type: application/json');

$data       = json_decode(file_get_contents('php://input'), true);
$student_no = trim($data['student_no'] ?? '');

if ($student_no === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Missing student number']);
    exit;
}

// Must be a real student — no logging of any student number someone
// happens to post.
$check = $conn->prepare("SELECT 1 FROM students_tbl WHERE student_no = ? LIMIT 1");
$check->bind_param('s', $student_no);
$check->execute();

if ($check->get_result()->num_rows === 0) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Student not found']);
    exit;
}

$version = TERMS_VERSION;
$ip      = substr($_SERVER['REMOTE_ADDR'] ?? '', 0, 45);

// (student_no, terms_version) has a UNIQUE KEY: accepting again just
// updates the timestamp rather than adding another row.
$stmt = $conn->prepare("
    INSERT INTO student_terms_tbl (student_no, terms_version, accepted_at, ip_address)
    VALUES (?, ?, NOW(), ?)
    ON DUPLICATE KEY UPDATE accepted_at = NOW(), ip_address = VALUES(ip_address)
");
$stmt->bind_param('sis', $student_no, $version, $ip);

if ($stmt->execute()) {
    echo json_encode(['success' => true, 'version' => $version]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Could not record acceptance']);
}
