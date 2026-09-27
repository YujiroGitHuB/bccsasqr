<?php
// ============================================================
// Switch the QR scanner's late marking on or off for one subject.
//
// On: every scan from now on is saved as late. Off: on time. There is
// no cutoff time on the scanner — the instructor flips the switch when
// the class has started. Keyed by (signed-in instructor, subject);
// see includes/late.php. The rule itself is scan_set_late() in
// includes/scan_attendance.php, shared with the phone app.
//
// Accepts (POST):
//   subject_code  required
//   on            1 | 0
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/scan_attendance.php";

header('Content-Type: application/json');

if (empty($_SESSION['user_id'])) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('sign-in');
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit;
}

requirePermissionJson('qr.scanner');

// The session, never the request: the switch is this instructor's own.
echo json_encode(scan_set_late(
    $conn,
    (int) $_SESSION['user_id'],
    (string) ($_POST['subject_code'] ?? ''),
    ($_POST['on'] ?? '') === '1'
));

$conn->close();
