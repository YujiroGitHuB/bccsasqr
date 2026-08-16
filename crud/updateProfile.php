<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
header("Content-Type: application/json");

$userId = $_SESSION['user_id'] ?? 0;

if (!$userId) {
    echo json_encode(["status" => "error", "message" => "Unauthorized."]);
    exit;
}

// Everyone may edit their own profile — there is no user_id in the
// request, so "their own" is the only thing this endpoint can reach.
// The email is the exception: it is the sign-in address, so only an
// admin may change one. The field is rendered readonly in
// pages/profile.php, but readonly is a hint to the browser and not a
// guard, so it is enforced here too.
$canChangeEmail = isAdmin();

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

// ── Face recognition ────────────────────────────────────────
// Same shape as registration writes (crud/reg_process.php): a JSON
// array of descriptors, each 128 floats. The browser produced it, so
// none of it is trusted — a descriptor that does not decode to that
// exact shape is rejected rather than stored, because a malformed row
// here would break face login for everyone: crud/get_face_users.php
// hands the whole table to the client and one bad entry throws.
$faceDescriptor = trim($_POST['faceDescriptor'] ?? '');
$removeFace     = ($_POST['remove_face'] ?? '0') === '1';

$faceChanged = false;
$faceValue   = null;
$faceEnabled = 0;

if ($removeFace) {
    $faceChanged = true;          // faceValue stays null, faceEnabled stays 0
} elseif ($faceDescriptor !== '') {
    $decoded = json_decode($faceDescriptor, true);

    $shapeOk = is_array($decoded) && count($decoded) > 0 && count($decoded) <= 10;
    if ($shapeOk) {
        foreach ($decoded as $one) {
            if (!is_array($one) || count($one) !== 128) {
                $shapeOk = false;
                break;
            }
            foreach ($one as $n) {
                if (!is_numeric($n)) {
                    $shapeOk = false;
                    break 2;
                }
            }
        }
    }

    if (!$shapeOk) {
        echo json_encode([
            "status"  => "error",
            "message" => "The face data was not in the expected format. Please capture again."
        ]);
        exit;
    }

    // Re-encoded from the decoded value, so whatever reaches the column
    // is canonical JSON and not the raw string off the wire.
    $faceChanged = true;
    $faceValue   = json_encode($decoded);
    $faceEnabled = 1;
}

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

// ── Confirm it is really them ───────────────────────────────
// The password and the face are the two ways into this account, so
// changing either is re-authenticated here. Without it, anyone who
// reaches an unattended signed-in browser can set their own face as a
// login credential and keep access indefinitely — quietly, since it
// changes nothing the owner would notice.
//
// Name, email and avatar deliberately do NOT ask: they are not
// credentials, and prompting for every trivial edit trains people to
// type their password without reading why.
$currentPassword   = (string)($_POST['current_password'] ?? '');
$needsConfirmation = ($password !== '') || $faceChanged;

if ($needsConfirmation) {
    $cred = $conn->prepare("SELECT password FROM users WHERE id = ? LIMIT 1");
    $cred->bind_param("i", $userId);
    $cred->execute();
    $storedHash = (string)($cred->get_result()->fetch_assoc()['password'] ?? '');
    $cred->close();

    if ($currentPassword === '') {
        echo json_encode([
            "status"  => "warning",
            "message" => "Enter your current password to change your password or your face.",
            "field"   => "current_password"
        ]);
        exit;
    }

    if ($storedHash === '' || !password_verify($currentPassword, $storedHash)) {
        echo json_encode([
            "status"  => "warning",
            "message" => "That is not your current password.",
            "field"   => "current_password"
        ]);
        exit;
    }
}

// Non-admins keep the email they signed in with. Compared against the
// stored value rather than trusted from the form, so a tampered request
// is caught. Matching values pass silently — the form always submits
// the field, unchanged, which is not an attempt to change anything.
if (!$canChangeEmail) {
    $own = $conn->prepare("SELECT email FROM users WHERE id = ? LIMIT 1");
    $own->bind_param("i", $userId);
    $own->execute();
    $currentEmail = (string)($own->get_result()->fetch_assoc()['email'] ?? '');
    $own->close();

    if (strcasecmp($email, $currentEmail) !== 0) {
        echo json_encode([
            "status"  => "warning",
            "message" => "Your email address is your sign-in address. Please ask an administrator to change it."
        ]);
        exit;
    }

    // Use the stored value so a difference in letter case cannot slip
    // through the comparison above and rewrite the row.
    $email = $currentEmail;
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

if ($faceChanged) {
    // Both columns move together. face_enabled on its own would leave a
    // stale descriptor behind that crud/get_face_users.php still serves,
    // and a descriptor without the flag would never be used.
    $sets[]   = "face_descriptor = ?";
    $types   .= "s";
    $values[] = $faceValue; // NULL when removed

    $sets[]   = "face_enabled = ?";
    $types   .= "i";
    $values[] = $faceEnabled;
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
        // Lets pages/profile.php redraw the face card without a reload.
        "face_changed"   => $faceChanged,
        "face_enabled"   => $faceChanged ? (bool) $faceEnabled : null,
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Update failed."]);
}
$stmt->close();
