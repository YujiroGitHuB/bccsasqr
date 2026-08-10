<?php
// ============================================================
// Itinatala ang pagtanggap ng estudyante sa Terms and Conditions
// bago siya makagawa ng QR.
//
// Bukas ito sa publiko tulad ng QR generator mismo (walang login
// ang estudyante), kaya:
//   - tinatanggap lang ang student_no na talagang nasa students_tbl
//   - ang bersyon ay galing sa server, hindi sa client — hindi
//     maipagpipilitan ng kahit sino ang ibang bersyon
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

// Dapat totoong estudyante — hindi tayo nagtatala ng basta-basta
// ipinadalang student number.
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

// May UNIQUE KEY ang (student_no, terms_version): kapag tinanggap
// niyang muli, ina-update lang ang oras sa halip na magdagdag ng
// bagong row.
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
