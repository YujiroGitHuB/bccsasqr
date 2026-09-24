<?php
// ============================================================
// Set or remove the late cutoff of an attendance link.
//
// The link stays open either way — this only decides whether a
// submission is recorded as on time or late. Closing the link is
// crud/set_link_expiry.php.
//
// Accepts (POST):
//   short_code  required
//   and ONE of:
//     minutes=15   on time for the next 15 minutes
//     at=08:15     today, from <input type="time">
//     clear=1      no cutoff
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/links.php";
require_once __DIR__ . "/../includes/late.php";

header('Content-Type: application/json');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('sign-in');
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit();
}

requirePermissionJson('links.manage');

$user_id   = (int) $_SESSION['user_id'];
$user_role = $_SESSION['role'];

$short_code = trim($_POST['short_code'] ?? '');
if ($short_code === '') {
    echo json_encode(['success' => false, 'message' => 'Short code required']);
    exit();
}

// ── The link must be yours ───────────────────────────────────
// Same rule as crud/set_link_expiry.php: an admin can change any
// link, an instructor only their own.
if ($user_role === 'admin') {
    $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
    $own->bind_param("s", $short_code);
} else {
    $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ? AND instructor_id = ?");
    $own->bind_param("si", $short_code, $user_id);
}
$own->execute();

if ($own->get_result()->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to change.']);
    exit();
}

if (!late_ready($conn)) {
    echo json_encode(['success' => false, 'message' => 'Late marking is not available yet — the database could not be updated.']);
    exit();
}

// ── The new cutoff ───────────────────────────────────────────
$clause = late_clause($_POST);

if ($clause['error'] !== null) {
    echo json_encode(['success' => false, 'message' => $clause['error']]);
    exit();
}

if ($clause['sql'] === null) {
    echo json_encode(['success' => false, 'message' => 'Nothing to set.']);
    exit();
}

$stmt   = $conn->prepare("UPDATE attendance_links_tbl SET {$clause['sql']} WHERE short_code = ?");
$types  = $clause['types'] . 's';
$params = array_merge($clause['params'], [$short_code]);
$stmt->bind_param($types, ...$params);

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Database error']);
    exit();
}

echo json_encode(array_merge(['success' => true], link_state($conn, $short_code)));

$conn->close();
