<?php
// Errors are logged, never printed: a PHP warning in the middle of this
// JSON broke the scan it belonged to, and printed the server's file
// paths to whoever was holding the phone.
error_reporting(E_ALL);
ini_set('display_errors', 0);

session_start();
include "../includes/db_connect.php";
include "../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/scan_attendance.php";

header('Content-Type: application/json');

requirePermissionJson('attendance.record');

// The rules themselves — who may scan which subject, duplicates, the
// photo requirement, late marking — live in includes/scan_attendance.php,
// shared with the phone app's scanner (api/v1/handlers/scanner.php).
//
// Only WHICH student and WHICH subject are taken from the request. Who
// is scanning comes from the session, when from the server's clock.
try {
    $data = json_decode(file_get_contents('php://input'), true);

    $result = scan_record(
        $conn,
        (int) ($_SESSION['user_id'] ?? 0),
        (string) ($data['id']           ?? ''),
        (string) ($data['subject_code'] ?? '')
    );

    // The photo's stored path, relative to this endpoint — the page
    // loads it from Qrscanner/, one level down from the site root.
    if (array_key_exists('photo_path', $result)) {
        $result['photo_url'] = $result['photo_path'] !== null ? '../' . $result['photo_path'] : null;
        unset($result['photo_path']);
    }

    echo json_encode($result);
    $conn->close();
} catch (Throwable $e) {
    // The detail goes to the server log. The phone gets a sentence — the
    // stack trace it used to get named every file and path on the server.
    error_log('save_attendance: ' . $e->getMessage() . ' | ' . $e->getTraceAsString());
    echo json_encode([
        'success' => false,
        'message' => 'error',
        'error'   => 'Could not save attendance. Please try again.'
    ]);
}
