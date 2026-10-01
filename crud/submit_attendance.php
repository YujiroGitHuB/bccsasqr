<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/link_checkin.php";
date_default_timezone_set('Asia/Manila');
header('Content-Type: application/json');

// The student's attendance-link form (pages/daily_attendance.php).
// Every check lives in includes/link_checkin.php, which the app's
// Check in uses too — this file only reads the form and the device
// cookie, and sends the answer back.

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit();
}

// ── Validate required fields ──────────────────────────────────────────────────
$required = ['student_no', 'short_code'];
foreach ($required as $field) {
    if (empty($_POST[$field])) {
        echo json_encode(['success' => false, 'message' => ucfirst(str_replace('_', ' ', $field)) . ' is required']);
        exit();
    }
}

// Who is holding the phone. The device id is a cookie the server
// signs; the fingerprint comes from the browser and is not trusted —
// it is kept for the record only, so there is a trail when the cookie
// is cleared.
$outcome = link_checkin($conn, [
    'student_no'  => trim($_POST['student_no']),
    'short_code'  => trim($_POST['short_code']),
    'device_id'   => integrity_device_id($conn),
    'fingerprint' => substr(preg_replace('/[^a-f0-9]/', '', strtolower($_POST['fp'] ?? '')), 0, 16),
    'ip'          => integrity_client_ip(),
]);

echo json_encode($outcome['response']);

$conn->close();
