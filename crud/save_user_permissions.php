<?php
// ============================================================
//  save_user_permissions.php — what one instructor is allowed to do
//
//  Replaces the whole set rather than diffing it: the modal always
//  submits every box's state, so "not in the request" genuinely
//  means "revoked". setUserPermissions() drops anything that is not
//  in PERMISSION_CATALOG, so a hand-crafted POST cannot invent
//  permissions or write junk rows.
// ============================================================
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

function replyPerm(string $status, string $message, array $extra = []): never {
    echo json_encode(array_merge(['status' => $status, 'message' => $message], $extra));
    exit;
}

if (!isAdmin()) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('admin: change permissions');
    replyPerm('error', 'Unauthorized.');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    replyPerm('error', 'Invalid request method.');
}

$userId = (int)($_POST['user_id'] ?? 0);
if ($userId <= 0) {
    replyPerm('warning', 'Please choose a user first.');
}

// `permissions[]` is absent entirely when every box is unticked —
// that is a valid instruction (revoke everything), not a bad request.
$requested = $_POST['permissions'] ?? [];
if (!is_array($requested)) {
    $requested = [];
}

$stmt = $conn->prepare("SELECT name, role FROM users WHERE id = ? LIMIT 1");
$stmt->bind_param("i", $userId);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    replyPerm('error', 'User not found.');
}

// Admins are answered by isAdmin() before can() ever reads the table,
// so rows for them would be decoration that quietly does nothing.
// Better to say so than to accept a save that has no effect.
if ($user['role'] === 'admin') {
    replyPerm('warning', 'Admins already have full access. Change the role to instructor first to limit it.');
}

if (!setUserPermissions($conn, $userId, $requested, (int)$_SESSION['user_id'])) {
    replyPerm('error', 'Could not save the permissions. Please try again.');
}

$granted = count(array_intersect(allPermissionKeys(), $requested));

// ── Also apply to ───────────────────────────────────────────
// Giving five instructors the same access used to mean opening the
// modal five times and ticking the same boxes five times. The modal
// can now name other instructors to receive the exact set just saved.
//
// Each one goes through setUserPermissions() like the first, so the
// same catalog filter applies. Admins are skipped for the same reason
// as above, and the user being edited is not counted twice.
$alsoIds = array_values(array_unique(array_filter(
    array_map('intval', (array)($_POST['also_user_ids'] ?? [])),
    static fn(int $id) => $id > 0 && $id !== $userId
)));

$applied = [];
$failed  = [];

if ($alsoIds) {
    $placeholders = implode(',', array_fill(0, count($alsoIds), '?'));
    $stmt = $conn->prepare("SELECT id, name FROM users WHERE role = 'instructor' AND id IN ($placeholders)");
    $stmt->bind_param(str_repeat('i', count($alsoIds)), ...$alsoIds);
    $stmt->execute();
    $targets = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    foreach ($targets as $target) {
        if (setUserPermissions($conn, (int)$target['id'], $requested, (int)$_SESSION['user_id'])) {
            $applied[] = $target['name'];
        } else {
            $failed[] = $target['name'];
        }
    }
}

$name = htmlspecialchars($user['name']);

if ($failed) {
    replyPerm('warning',
        'Saved for ' . $name . ($applied ? ' and ' . count($applied) . ' more' : '')
        . ', but not for ' . htmlspecialchars(implode(', ', $failed)) . '. Please try those again.',
        ['granted' => $granted]
    );
}

if ($applied) {
    replyPerm('success',
        'Access updated for ' . $name . ' and ' . count($applied) . ' other instructor' . (count($applied) === 1 ? '' : 's') . '.',
        ['granted' => $granted, 'applied' => count($applied)]
    );
}

replyPerm('success', $granted === 0
    ? $name . ' now has dashboard access only.'
    : 'Access updated for ' . $name . '.',
    ['granted' => $granted]
);
