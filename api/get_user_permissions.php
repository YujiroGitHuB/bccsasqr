<?php
// ============================================================
//  api/get_user_permissions.php
//
//  The keys currently granted to one user, for the Manage Access
//  modal to tick. The catalog itself is rendered server-side from
//  PERMISSION_CATALOG (see pages/manage_users.php) — only the
//  answers travel over the wire.
// ============================================================
session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

if (!isAdmin()) {
    echo json_encode(['status' => 'error', 'message' => 'Unauthorized.']);
    exit;
}

$userId = (int)($_GET['user_id'] ?? 0);
if ($userId <= 0) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid user.']);
    exit;
}

$stmt = $conn->prepare("SELECT name, role FROM users WHERE id = ? LIMIT 1");
$stmt->bind_param("i", $userId);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    echo json_encode(['status' => 'error', 'message' => 'User not found.']);
    exit;
}

echo json_encode([
    'status'      => 'success',
    'name'        => $user['name'],
    'role'        => $user['role'],
    // An admin has no stored rows — they pass every check by role.
    // Reporting the full catalog keeps the modal honest if it is ever
    // opened for one.
    'permissions' => $user['role'] === 'admin'
        ? allPermissionKeys()
        : userPermissions($userId),
]);
