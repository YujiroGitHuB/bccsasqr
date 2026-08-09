<?php
// ============================================================
//  student_photo_api.php  —  SECURED & WORKING
// ============================================================

// Suppress ALL output before JSON — critical on free hosting
ob_start();
ini_set('display_errors', 0);
error_reporting(0);

@ini_set('post_max_size',  '10M');
@ini_set('memory_limit',   '64M');

header('Content-Type: application/json');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: strict-origin-when-cross-origin');

session_start();
include "../includes/db_connect.php";

define('PHOTO_UPLOAD_DIR', $_SERVER['DOCUMENT_ROOT'] . '/bccsasqr/uploads/photos/');
define('PHOTO_URL_BASE',   'uploads/photos/');
define('MAX_ATTEMPTS',     5);
define('LOCKOUT_SECONDS',  15 * 60);

$action = $_GET['action'] ?? '';

// ── Clean JSON output helper ──────────────────────────────
function sendJson(array $data): never {
    ob_clean(); // wipe any stray output (PHP warnings, notices, etc.)
    echo json_encode($data);
    exit;
}

// ── Rate limiter ──────────────────────────────────────────
function getRlKey(): string {
    return 'rl_photo_upload';
}

function checkRateLimit(): void {
    $key = getRlKey();
    $now = time();

    if (!isset($_SESSION[$key])) {
        $_SESSION[$key] = ['count' => 0, 'since' => $now];
    }

    if ($now - $_SESSION[$key]['since'] > LOCKOUT_SECONDS) {
        $_SESSION[$key] = ['count' => 0, 'since' => $now];
    }

    if ($_SESSION[$key]['count'] >= MAX_ATTEMPTS) {
        $wait = ceil((LOCKOUT_SECONDS - ($now - $_SESSION[$key]['since'])) / 60);
        sendJson([
            'success' => false,
            'locked'  => true,
            'message' => "Too many failed attempts. Try again in {$wait} minute(s).",
        ]);
    }
}

function recordFailure(): void {
    $key = getRlKey();
    if (!isset($_SESSION[$key])) {
        $_SESSION[$key] = ['count' => 0, 'since' => time()];
    }
    $_SESSION[$key]['count']++;
}

function clearRateLimit(): void {
    unset($_SESSION[getRlKey()]);
}

// ── CSRF helpers ──────────────────────────────────────────
function getCsrfToken(): string {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function checkCsrf(string $token): void {
    if (empty($_SESSION['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $token)) {
        sendJson(['success' => false, 'message' => 'Invalid session token. Please refresh the page.']);
    }
}

// ─────────────────────────────────────────────────────────
//  get_token
// ─────────────────────────────────────────────────────────
if ($action === 'get_token') {
    sendJson(['success' => true, 'token' => getCsrfToken()]);
}

// ─────────────────────────────────────────────────────────
//  verify
// ─────────────────────────────────────────────────────────
if ($action === 'verify' && $_SERVER['REQUEST_METHOD'] === 'GET') {

    checkRateLimit();

    $student_no = trim($_GET['student_id'] ?? '');
    $last_name  = strtoupper(trim($_GET['last_name'] ?? ''));

    if ($student_no === '' || $last_name === '') {
        sendJson(['success' => false, 'message' => 'Please fill in all fields.']);
    }

    $student_no = preg_replace('/[^a-zA-Z0-9\-]/', '', $student_no);
    $last_name  = preg_replace('/[^A-Za-zÀ-ÿ\s\-\'\.]/u', '', $last_name);

    if (empty($student_no) || empty($last_name)) {
        recordFailure();
        sendJson(['success' => false, 'message' => 'Invalid input characters.']);
    }

    $stmt = $conn->prepare("
        SELECT id, fullname, course, section
        FROM students_tbl
        WHERE student_no = ?
        LIMIT 1
    ");

    if (!$stmt) {
        sendJson(['success' => false, 'message' => 'Database error. Please try again.']);
    }

    $stmt->bind_param("s", $student_no);
    $stmt->execute();
    $student = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $db_lastname = '';
    if ($student) {
        $parts       = explode(',', $student['fullname']);
        $db_lastname = strtoupper(trim($parts[0]));
    }

    if (!$student || $db_lastname !== $last_name) {
        recordFailure();
        $attempts_left = max(0, MAX_ATTEMPTS - ($_SESSION[getRlKey()]['count'] ?? 0));
        sendJson([
            'success' => false,
            'message' => "Incorrect student number or last name. {$attempts_left} attempt(s) remaining.",
        ]);
    }

    clearRateLimit();

    $_SESSION['verified_student_id'] = (int) $student['id'];
    $_SESSION['verified_at']         = time();

    unset($_SESSION['csrf_token']);

    sendJson([
        'success' => true,
        'token'   => getCsrfToken(),
        'student' => [
            'id'         => (int) $student['id'],
            'name'       => $student['fullname'],
            'course'     => $student['course']  ?? '',
            'year_level' => $student['section'] ?? '',
        ],
    ]);
}

// ─────────────────────────────────────────────────────────
//  save — supports both FormData and JSON POST
// ─────────────────────────────────────────────────────────
if ($action === 'save' && $_SERVER['REQUEST_METHOD'] === 'POST') {

    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    $isJson      = str_contains($contentType, 'application/json');

    if ($isJson) {
        // Legacy JSON path
        $raw  = file_get_contents('php://input');

        if (empty($raw) && isset($_SERVER['CONTENT_LENGTH']) && (int)$_SERVER['CONTENT_LENGTH'] > 0) {
            sendJson(['success' => false, 'message' => 'Upload too large. Ask admin to increase post_max_size.']);
        }

        $body = json_decode($raw, true);
        if (!is_array($body)) {
            sendJson(['success' => false, 'message' => 'Invalid request body.']);
        }
    } else {
        // FormData path — data is in $_POST directly
        $body = $_POST;
    }

    // CSRF check
    checkCsrf($body['_token'] ?? '');

    // Session check
    $verified_id = $_SESSION['verified_student_id'] ?? null;
    $verified_at = $_SESSION['verified_at']         ?? 0;

    if (!$verified_id || (time() - $verified_at) > 600) {
        sendJson(['success' => false, 'message' => 'Session expired. Please verify your ID again.']);
    }

    $db_id      = intval($body['student_id'] ?? 0);
    $photo_data = $body['photo_data'] ?? '';

    if ($db_id !== (int) $verified_id) {
        sendJson(['success' => false, 'message' => 'Unauthorized.']);
    }

    if (empty($photo_data)) {
        sendJson(['success' => false, 'message' => 'No photo received.']);
    }

    if (!preg_match('/^data:image\/(jpeg|png|webp);base64,/', $photo_data)) {
        sendJson(['success' => false, 'message' => 'Invalid image format.']);
    }

    $image_data = base64_decode(
        preg_replace('/^data:image\/[a-z]+;base64,/', '', $photo_data),
        true
    );

    if ($image_data === false || strlen($image_data) < 500) {
        sendJson(['success' => false, 'message' => 'Could not decode image.']);
    }

    if (strlen($image_data) > 1 * 1024 * 1024) {
        sendJson(['success' => false, 'message' => 'Image too large (max 1MB).']);
    }

    $img_info = @getimagesizefromstring($image_data);
    if ($img_info === false) {
        sendJson(['success' => false, 'message' => 'File is not a valid image.']);
    }

    $allowed_types = [IMAGETYPE_JPEG, IMAGETYPE_PNG, IMAGETYPE_WEBP];
    if (!in_array($img_info[2], $allowed_types)) {
        sendJson(['success' => false, 'message' => 'Only JPG, PNG, and WEBP are allowed.']);
    }

    if (!is_dir(PHOTO_UPLOAD_DIR)) {
        mkdir(PHOTO_UPLOAD_DIR, 0755, true);
    }

    $filename = 'student_' . $db_id . '.jpg';
    $filepath = PHOTO_UPLOAD_DIR . $filename;

    foreach (['png', 'webp'] as $ext) {
        $old = PHOTO_UPLOAD_DIR . 'student_' . $db_id . '.' . $ext;
        if (file_exists($old)) @unlink($old);
    }

    if (file_put_contents($filepath, $image_data) === false) {
        sendJson(['success' => false, 'message' => 'Failed to save file. Check folder permissions.']);
    }
    @chmod($filepath, 0644);

    $photo_path = PHOTO_URL_BASE . $filename;
    $upd = $conn->prepare("
        INSERT INTO student_photos (s_id, photo_path)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE
            photo_path = VALUES(photo_path),
            updated_at = NOW()
    ");

    if (!$upd) {
        sendJson(['success' => false, 'message' => 'Database error.']);
    }

    $upd->bind_param("is", $db_id, $photo_path);
    $upd->execute();
    $upd->close();

    unset($_SESSION['verified_student_id'], $_SESSION['verified_at'], $_SESSION['csrf_token']);

    sendJson([
        'success'   => true,
        'photo_url' => $photo_path,
        'message'   => 'Photo saved successfully.',
    ]);
}

// Unknown action
sendJson(['success' => false, 'message' => 'Unknown action.']);