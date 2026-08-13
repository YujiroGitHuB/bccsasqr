<?php
// ============================================================
//  save_user.php — creating and editing user accounts
//
//  There was no equivalent before: the only way to get an account
//  was the public reg.php, and the role it handed out was always
//  instructor. An admin had no way to promote anyone, change an
//  email, or reset a forgotten password.
//
//  Add and edit share one endpoint: the rules are the same, only the
//  password differs (required when new, optional on edit).
// ============================================================
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

const MIN_PASSWORD_LEN = 8;

function reply(string $status, string $message, array $extra = []): never {
    echo json_encode(array_merge(['status' => $status, 'message' => $message], $extra));
    exit;
}

if (!isAdmin()) {
    reply('error', 'Unauthorized.');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    reply('error', 'Invalid request method.');
}

$userId   = (int)($_POST['user_id'] ?? 0);   // 0 = bagong user
$name     = trim($_POST['name'] ?? '');
$email    = trim($_POST['email'] ?? '');
$role     = trim($_POST['role'] ?? '');
$password = trim($_POST['password'] ?? '');
$isEdit   = $userId > 0;

// ── Validation ──────────────────────────────────────────────
if ($name === '' || $email === '') {
    reply('warning', 'Name and email are required.');
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    reply('warning', 'Please enter a valid email address.');
}

if (!in_array($role, ['admin', 'instructor'], true)) {
    reply('warning', 'Please choose a valid role.');
}

if (!$isEdit && $password === '') {
    reply('warning', 'A password is required for a new user.');
}

if ($password !== '' && strlen($password) < MIN_PASSWORD_LEN) {
    reply('warning', 'Password must be at least ' . MIN_PASSWORD_LEN . ' characters.');
}

// email is a UNIQUE KEY — our own message is clearer than MySQL's
// raw "Duplicate entry".
$dupe = $conn->prepare("SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1");
$dupe->bind_param("si", $email, $userId);
$dupe->execute();
$taken = $dupe->get_result()->num_rows > 0;
$dupe->close();

if ($taken) {
    reply('warning', 'That email is already used by another account.');
}

// ── Guards on editing ───────────────────────────────────────
if ($isEdit) {
    $cur = $conn->prepare("SELECT role, IFNULL(status,'active') as status FROM users WHERE id = ?");
    $cur->bind_param("i", $userId);
    $cur->execute();
    $existing = $cur->get_result()->fetch_assoc();
    $cur->close();

    if (!$existing) {
        reply('error', 'User not found.');
    }

    // An admin cannot demote themselves — in a one-admin system that
    // means permanently losing access to Manage Users and Settings.
    if ($userId === (int)$_SESSION['user_id'] && $role !== $existing['role']) {
        reply('warning', 'You cannot change your own role.');
    }

    // At least one active admin must always remain. Otherwise nobody
    // can reach the admin pages — even re-enabling one requires an
    // admin.
    if ($existing['role'] === 'admin' && $role !== 'admin') {
        $left = (int) $conn->query("
            SELECT COUNT(*) as c FROM users
            WHERE role = 'admin' AND IFNULL(status,'active') = 'active'
        ")->fetch_assoc()['c'];

        if ($left <= 1) {
            reply('warning', 'This is the last active admin. Promote someone else first.');
        }
    }
}

// ── The save itself ─────────────────────────────────────────
if ($isEdit) {

    if ($password !== '') {
        $hash = password_hash($password, PASSWORD_ARGON2ID);
        $stmt = $conn->prepare("UPDATE users SET name = ?, email = ?, role = ?, password = ? WHERE id = ?");
        $stmt->bind_param("ssssi", $name, $email, $role, $hash, $userId);
    } else {
        $stmt = $conn->prepare("UPDATE users SET name = ?, email = ?, role = ? WHERE id = ?");
        $stmt->bind_param("sssi", $name, $email, $role, $userId);
    }

    $ok      = $stmt->execute();
    $message = $password !== ''
        ? 'User updated and password reset.'
        : 'User updated successfully.';

    // If you edited yourself, the topbar has to follow.
    if ($ok && $userId === (int)$_SESSION['user_id']) {
        $_SESSION['user_name'] = $name;
    }

    // An admin demoted to instructor has no permission rows of their
    // own — as an admin they never needed any. Without seeding, they
    // would land on a dashboard with nothing else on it.
    if ($ok && $role === 'instructor' && $existing['role'] !== 'instructor') {
        seedDefaultPermissions($conn, $userId);
    }

} else {

    $hash = password_hash($password, PASSWORD_ARGON2ID);
    $stmt = $conn->prepare("
        INSERT INTO users (name, email, password, role, status)
        VALUES (?, ?, ?, ?, 'active')
    ");
    $stmt->bind_param("ssss", $name, $email, $hash, $role);

    $ok      = $stmt->execute();
    $message = 'User created successfully.';

    // New instructors start with the standard set; the admin narrows
    // it down afterwards from Manage Users → Access.
    if ($ok && $role === 'instructor') {
        seedDefaultPermissions($conn, $conn->insert_id);
    }
}

if (!$ok) {
    $stmt->close();
    reply('error', 'Could not save the user. Please try again.');
}
$stmt->close();

reply('success', $message);
