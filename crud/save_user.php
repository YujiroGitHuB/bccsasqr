<?php
// ============================================================
//  save_user.php — paggawa at pag-edit ng user account
//
//  Wala nitong katumbas noon: ang tanging paraan para magkaroon ng
//  account ay ang pampublikong reg.php, at instructor lagi ang role
//  na naibibigay noon. Walang paraan ang admin na mag-promote,
//  magpalit ng email, o mag-reset ng nakalimutang password.
//
//  Iisang endpoint ang add at edit: pareho ang mga patakaran, ang
//  password lang ang naiiba (kailangan sa bago, opsyonal sa edit).
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

// UNIQUE KEY ang email — mas malinaw ang sariling mensahe kaysa sa
// hilaw na "Duplicate entry" mula sa MySQL.
$dupe = $conn->prepare("SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1");
$dupe->bind_param("si", $email, $userId);
$dupe->execute();
$taken = $dupe->get_result()->num_rows > 0;
$dupe->close();

if ($taken) {
    reply('warning', 'That email is already used by another account.');
}

// ── Mga proteksyon sa pag-edit ──────────────────────────────
if ($isEdit) {
    $cur = $conn->prepare("SELECT role, IFNULL(status,'active') as status FROM users WHERE id = ?");
    $cur->bind_param("i", $userId);
    $cur->execute();
    $existing = $cur->get_result()->fetch_assoc();
    $cur->close();

    if (!$existing) {
        reply('error', 'User not found.');
    }

    // Hindi puwedeng i-demote ng admin ang sarili niya — sa isang
    // admin na system, iyon ay permanenteng pagkawala ng akses sa
    // Manage Users at Settings.
    if ($userId === (int)$_SESSION['user_id'] && $role !== $existing['role']) {
        reply('warning', 'You cannot change your own role.');
    }

    // Dapat laging may natitirang isang aktibong admin. Kung hindi,
    // walang makakapasok sa mga admin page — kahit ang pag-enable
    // pabalik ay nangangailangan ng admin.
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

// ── Ang mismong pag-save ────────────────────────────────────
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

    // Kung ang sarili ang na-edit, dapat sumabay ang topbar.
    if ($ok && $userId === (int)$_SESSION['user_id']) {
        $_SESSION['user_name'] = $name;
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
}

if (!$ok) {
    $stmt->close();
    reply('error', 'Could not save the user. Please try again.');
}
$stmt->close();

reply('success', $message);
