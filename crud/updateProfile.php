<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include __DIR__ . "/../includes/db_connect.php";
header("Content-Type: application/json");

$userId = $_SESSION['user_id'] ?? 0;

if (!$userId) {
    echo json_encode(["status" => "error", "message" => "Unauthorized."]);
    exit;
}

// ── Avatar constants ────────────────────────────────────────
// What is stored in the DB is a path relative to the app root (the
// same as student_photos.photo_path), so pages inside /pages only
// have to prepend "../".
define('AVATAR_DIR',      __DIR__ . '/../uploads/avatars/');
define('AVATAR_URL_BASE', 'uploads/avatars/');
define('AVATAR_MAX_BYTES', 2 * 1024 * 1024);
define('MIN_PASSWORD_LEN', 8);

$name     = trim($_POST['name'] ?? '');
$email    = trim($_POST['email'] ?? '');
$password = trim($_POST['password'] ?? '');
$remove   = ($_POST['remove_avatar'] ?? '0') === '1';

if ($name === '' || $email === '') {
    echo json_encode(["status" => "warning", "message" => "Name and email cannot be empty."]);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(["status" => "warning", "message" => "Please enter a valid email address."]);
    exit;
}

if ($password !== '' && strlen($password) < MIN_PASSWORD_LEN) {
    echo json_encode([
        "status"  => "warning",
        "message" => "Password must be at least " . MIN_PASSWORD_LEN . " characters."
    ]);
    exit;
}

// email is a UNIQUE KEY on users. Without checking here, the user
// only sees "Update failed." and never learns that another account
// already holds that email.
$dupe = $conn->prepare("SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1");
$dupe->bind_param("si", $email, $userId);
$dupe->execute();
$taken = $dupe->get_result()->num_rows > 0;
$dupe->close();

if ($taken) {
    echo json_encode(["status" => "warning", "message" => "That email is already used by another account."]);
    exit;
}

// ── May avatar column ba? ───────────────────────────────────
// Requires migrations/2026-08-10_add_user_avatar.sql. If that has not
// been run on this server, saving name/email/password still goes
// through rather than the whole form throwing a fatal error.
$hasAvatarColumn = false;
try {
    $col = $conn->query("SHOW COLUMNS FROM users LIKE 'avatar'");
    $hasAvatarColumn = $col && $col->num_rows > 0;
} catch (Throwable $e) {
    $hasAvatarColumn = false;
}

$avatarPath    = null;  // bagong path na ise-save
$avatarChanged = false;
$avatarRemoved = false;

if ($hasAvatarColumn) {
    // The current path — needed to know which file on disk to delete
    // when it is replaced or removed.
    $cur = $conn->prepare("SELECT avatar FROM users WHERE id = ?");
    $cur->bind_param("i", $userId);
    $cur->execute();
    $currentAvatar = (string)($cur->get_result()->fetch_assoc()['avatar'] ?? '');
    $cur->close();

    $file = $_FILES['avatar'] ?? null;
    $hasUpload = $file && ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE;

    if ($hasUpload) {

        if ($file['error'] !== UPLOAD_ERR_OK) {
            $msg = in_array($file['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)
                ? "Image is too large for this server's upload limit."
                : "Upload failed. Please try again.";
            echo json_encode(["status" => "error", "message" => $msg]);
            exit;
        }

        if (!is_uploaded_file($file['tmp_name'])) {
            echo json_encode(["status" => "error", "message" => "Invalid upload."]);
            exit;
        }

        if ($file['size'] > AVATAR_MAX_BYTES) {
            echo json_encode(["status" => "warning", "message" => "Image is too large (max 2 MB)."]);
            exit;
        }

        // The actual contents are checked, not the extension or the
        // client-supplied MIME — an attacker can fake either.
        $info = @getimagesize($file['tmp_name']);
        $allowed = [
            IMAGETYPE_JPEG => 'jpg',
            IMAGETYPE_PNG  => 'png',
            IMAGETYPE_WEBP => 'webp',
        ];

        if ($info === false || !isset($allowed[$info[2]])) {
            echo json_encode(["status" => "warning", "message" => "Only JPG, PNG, or WEBP images are allowed."]);
            exit;
        }

        $ext = $allowed[$info[2]];

        if (!is_dir(AVATAR_DIR) && !@mkdir(AVATAR_DIR, 0755, true) && !is_dir(AVATAR_DIR)) {
            echo json_encode(["status" => "error", "message" => "Cannot create the avatars folder. Check permissions."]);
            exit;
        }

        $filename = 'user_' . $userId . '.' . $ext;
        $target   = AVATAR_DIR . $filename;

        if (!move_uploaded_file($file['tmp_name'], $target)) {
            echo json_encode(["status" => "error", "message" => "Failed to save the image. Check folder permissions."]);
            exit;
        }
        @chmod($target, 0644);

        // One file per user — clean up the old extension (e.g.
        // user_1.png replaced by user_1.jpg), otherwise it is left
        // orphaned in the uploads folder forever.
        foreach (['jpg', 'png', 'webp'] as $other) {
            if ($other === $ext) continue;
            $stale = AVATAR_DIR . 'user_' . $userId . '.' . $other;
            if (is_file($stale)) @unlink($stale);
        }

        $avatarPath    = AVATAR_URL_BASE . $filename;
        $avatarChanged = true;

    } elseif ($remove) {

        foreach (['jpg', 'png', 'webp'] as $other) {
            $stale = AVATAR_DIR . 'user_' . $userId . '.' . $other;
            if (is_file($stale)) @unlink($stale);
        }

        // If the old path falls outside the standard naming (e.g. from
        // an earlier version), delete it too — but only within
        // uploads/avatars, so no other file can be touched.
        if ($currentAvatar !== '' && str_starts_with($currentAvatar, AVATAR_URL_BASE)) {
            $old = __DIR__ . '/../' . $currentAvatar;
            if (is_file($old)) @unlink($old);
        }

        $avatarPath    = null;
        $avatarChanged = true;
        $avatarRemoved = true;
    }
}

// ── The update itself ───────────────────────────────────────
$sets   = ["name = ?", "email = ?"];
$types  = "ss";
$values = [$name, $email];

if ($password !== '') {
    $sets[]   = "password = ?";
    $types   .= "s";
    $values[] = password_hash($password, PASSWORD_ARGON2ID);
}

if ($avatarChanged) {
    $sets[]   = "avatar = ?";
    $types   .= "s";
    $values[] = $avatarPath; // NULL when removed
}

$types   .= "i";
$values[] = $userId;

$stmt = $conn->prepare("UPDATE users SET " . implode(", ", $sets) . " WHERE id = ?");
$stmt->bind_param($types, ...$values);

if ($stmt->execute()) {
    // The topbar reads from the session, so without updating it the
    // name/photo would stay stale until the next login.
    $_SESSION['user_name'] = $name;
    if ($avatarChanged) {
        $_SESSION['user_avatar'] = $avatarPath;
    }

    echo json_encode([
        "status"         => "success",
        "message"        => "Profile updated successfully!",
        "avatar_url"     => $avatarChanged && $avatarPath !== null ? $avatarPath : null,
        "avatar_removed" => $avatarRemoved,
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Update failed."]);
}
$stmt->close();
