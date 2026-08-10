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
// Ang itinatago sa DB ay path na relatibo sa app root (kagaya ng
// student_photos.photo_path), kaya "../" lang ang idinadagdag ng
// mga page sa loob ng /pages.
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

// UNIQUE KEY ang email sa users. Kung hindi ito tsi-tsek dito,
// "Update failed." lang ang makikita ng user at hindi niya
// malalaman na naunahan na siya ng ibang account sa email na iyon.
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
// Kailangan ng migrations/2026-08-10_add_user_avatar.sql. Kung hindi
// pa iyon napapatakbo sa server na ito, tuloy pa rin ang pag-save ng
// pangalan/email/password sa halip na mag-fatal error ang buong form.
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
    // Kasalukuyang path — kailangan para malaman kung anong file ang
    // buburahin sa disk kapag pinalitan o tinanggal.
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

        // Ang totoong nilalaman ang sinusuri, hindi ang extension o
        // ang client-supplied na MIME — parehong nagagaya ng attacker.
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

        // Isang file lang kada user — linisin ang lumang extension
        // (hal. user_1.png na napalitan ng user_1.jpg), kung hindi ay
        // maiiwan itong orphan sa uploads folder magpakailanman.
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

        // Kung nasa labas ng standard na pangalan ang lumang path
        // (hal. galing sa naunang bersyon), burahin din — pero sa loob
        // lang ng uploads/avatars para hindi makagalaw ng ibang file.
        if ($currentAvatar !== '' && str_starts_with($currentAvatar, AVATAR_URL_BASE)) {
            $old = __DIR__ . '/../' . $currentAvatar;
            if (is_file($old)) @unlink($old);
        }

        $avatarPath    = null;
        $avatarChanged = true;
        $avatarRemoved = true;
    }
}

// ── Ang mismong update ──────────────────────────────────────
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
    $values[] = $avatarPath; // NULL kapag tinanggal
}

$types   .= "i";
$values[] = $userId;

$stmt = $conn->prepare("UPDATE users SET " . implode(", ", $sets) . " WHERE id = ?");
$stmt->bind_param($types, ...$values);

if ($stmt->execute()) {
    // Ang topbar ay nagbabasa mula sa session, kaya kung hindi ito
    // ita-update ay mananatiling luma ang pangalan/larawan hanggang
    // sa susunod na login.
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
