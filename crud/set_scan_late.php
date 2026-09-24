<?php
// ============================================================
// Set or remove the QR scanner's late cutoff for one subject.
//
// Same inputs and the same rules as crud/set_link_late.php — see
// includes/late.php — but keyed by (signed-in instructor, subject)
// instead of a link, because the scanner has no link.
//
// Accepts (POST):
//   subject_code  required
//   and ONE of:
//     minutes=15   on time for the next 15 minutes
//     at=08:15     today, from <input type="time">
//     clear=1      no cutoff
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

// The session, never the request: the cutoff is this instructor's own.
$user_id      = (int) $_SESSION['user_id'];
$subject_code = trim($_POST['subject_code'] ?? '');

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

$clause = late_clause($_POST);

if ($clause['error'] !== null) {
    echo json_encode(['success' => false, 'message' => $clause['error']]);
    exit;
}

if ($clause['sql'] === null) {
    echo json_encode(['success' => false, 'message' => 'Nothing to set.']);
    exit;
}

// The row first, then the same SET clause the link endpoint uses — one
// place builds late_after, whichever table it lands in.
$ins = $conn->prepare("INSERT IGNORE INTO scan_late_tbl (instructor_id, subject_code) VALUES (?, ?)");
$ins->bind_param('is', $user_id, $subject_code);
$ins->execute();

$stmt   = $conn->prepare("UPDATE scan_late_tbl SET {$clause['sql']} WHERE instructor_id = ? AND subject_code = ?");
$types  = $clause['types'] . 'is';
$params = array_merge($clause['params'], [$user_id, $subject_code]);
$stmt->bind_param($types, ...$params);

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Database error']);
    exit;
}

echo json_encode(array_merge(
    ['success' => true, 'subject_code' => $subject_code],
    late_scan_states($conn, $user_id, [$subject_code])[$subject_code]
));

$conn->close();
