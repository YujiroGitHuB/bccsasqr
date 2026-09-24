<?php
// ============================================================
// Switch the QR scanner's late marking on or off for one subject.
//
// On: every scan from now on is saved as late. Off: on time. There is
// no cutoff time on the scanner — the instructor flips the switch when
// the class has started. Keyed by (signed-in instructor, subject);
// see includes/late.php.
//
// Accepts (POST):
//   subject_code  required
//   on            1 | 0
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/late.php";

header('Content-Type: application/json');

if (empty($_SESSION['user_id'])) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('sign-in');
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit;
}

requirePermissionJson('qr.scanner');

// The session, never the request: the switch is this instructor's own.
$user_id      = (int) $_SESSION['user_id'];
$subject_code = trim($_POST['subject_code'] ?? '');
$on           = ($_POST['on'] ?? '') === '1';

if ($subject_code === '') {
    echo json_encode(['success' => false, 'message' => 'Select a subject first.']);
    exit;
}

// ── The subject must be yours ────────────────────────────────
// The same check crud/save_attendance.php makes before a scan: an
// admin can scan any subject, an instructor only an assigned one.
if (!isAdmin()) {
    $own = $conn->prepare("
        SELECT si.id
        FROM subject_instructors_tbl si
        INNER JOIN subjects_tbl s ON s.id = si.subject_id
        WHERE s.subject_code = ? AND si.instructor_id = ?
        LIMIT 1
    ");
    $own->bind_param('si', $subject_code, $user_id);
    $own->execute();

    if ($own->get_result()->num_rows === 0) {
        echo json_encode(['success' => false, 'message' => 'That subject is not assigned to you.']);
        exit;
    }
}

if (!late_scan_ready($conn)) {
    echo json_encode(['success' => false, 'message' => 'Late marking is not available yet — the database could not be updated.']);
    exit;
}

// On records the moment it was switched on — NOW(), on the database
// clock that also decides what "today" is. Off is NULL.
$stmt = $conn->prepare("
    INSERT INTO scan_late_tbl (instructor_id, subject_code, late_after)
    VALUES (?, ?, IF(?, NOW(), NULL))
    ON DUPLICATE KEY UPDATE late_after = VALUES(late_after)
");
$onInt = $on ? 1 : 0;
$stmt->bind_param('isi', $user_id, $subject_code, $onInt);

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Database error']);
    exit;
}

echo json_encode([
    'success'      => true,
    'subject_code' => $subject_code,
    'on'           => late_scan_now($conn, $user_id, $subject_code),
]);

$conn->close();
