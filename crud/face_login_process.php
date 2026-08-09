<?php
// ========================================
// FACE LOGIN PROCESS
// Handles face recognition login.
//
// SECURITY: The client does an initial match locally, but the server MUST
// re-verify the submitted face descriptor against the stored descriptor(s)
// for the claimed user_id. Without this, anyone could POST user_id=1 and log
// in as that user. The client is not trusted.
// ========================================

session_start();
header('Content-Type: application/json');
include __DIR__ . '/../includes/db_connect.php';

// Distance below which two face descriptors are considered the same person.
// Matches the client threshold (0.45); a small margin keeps legitimate logins
// from being rejected due to JSON float round-trip.
const FACE_MATCH_THRESHOLD = 0.50;

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit();
}

$userId = $_POST['user_id'] ?? '';

if (empty($userId)) {
    echo json_encode(['success' => false, 'message' => 'User ID is required']);
    exit();
}

// ── Parse the submitted face descriptor (128 floats) ──────────────────────────
$descriptorRaw = $_POST['descriptor'] ?? '';
$submitted     = json_decode($descriptorRaw, true);

if (!is_array($submitted) || count($submitted) !== 128) {
    echo json_encode(['success' => false, 'message' => 'Face verification required.']);
    exit();
}
foreach ($submitted as $v) {
    if (!is_numeric($v)) {
        echo json_encode(['success' => false, 'message' => 'Invalid face data.']);
        exit();
    }
}
$submitted = array_map('floatval', $submitted);

// ── Euclidean distance between two 128-length descriptors ─────────────────────
function faceDistance(array $a, array $b): float {
    $sum = 0.0;
    for ($i = 0; $i < 128; $i++) {
        $d = $a[$i] - ($b[$i] ?? 0);
        $sum += $d * $d;
    }
    return sqrt($sum);
}

try {
    // Get user details INCLUDING ROLE, STATUS and stored face descriptor(s)
    $stmt = $conn->prepare("
        SELECT id, name, email, role, status, face_enabled, face_descriptor
        FROM users
        WHERE id = ? AND face_enabled = 1
    ");

    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        echo json_encode(['success' => false, 'message' => 'User not found or face login not enabled']);
        $stmt->close();
        $conn->close();
        exit();
    }

    $user = $result->fetch_assoc();
    $stmt->close();

    // ── Verify the submitted face against the stored descriptor(s) ────────────
    $stored = json_decode($user['face_descriptor'] ?? '', true);
    if (!is_array($stored) || count($stored) === 0) {
        echo json_encode(['success' => false, 'message' => 'No face data on file for this account.']);
        $conn->close();
        exit();
    }

    // Normalize to a list of descriptors: single (128 floats) or multi (N×128).
    $descriptors = is_array($stored[0]) ? $stored : [$stored];

    $bestDistance = INF;
    foreach ($descriptors as $desc) {
        if (!is_array($desc) || count($desc) !== 128) continue;
        $dist = faceDistance($submitted, array_map('floatval', $desc));
        if ($dist < $bestDistance) $bestDistance = $dist;
    }

    if ($bestDistance > FACE_MATCH_THRESHOLD) {
        echo json_encode(['success' => false, 'message' => 'Face not recognized. Please try again or use password login.']);
        $conn->close();
        exit();
    }

    // CHECK IF ACCOUNT IS DISABLED (same as password login)
    $user_status = !empty($user['status']) ? $user['status'] : 'active';

    if ($user_status === 'disabled') {
        echo json_encode(['success' => false, 'message' => 'Your account has been disabled. Please contact the administrator.']);
        $conn->close();
        exit();
    }

    // Set session variables (SAME AS PASSWORD LOGIN)
    $_SESSION['user_id']      = $user['id'];
    $_SESSION['user_name']    = $user['name'];
    $_SESSION['user_email']   = $user['email'];
    $_SESSION['role']         = $user['role'];
    $_SESSION['login_method'] = 'face_recognition';
    $_SESSION['login_time']   = time();

    // Update last login
    $updateStmt = $conn->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
    $updateStmt->bind_param("i", $userId);
    $updateStmt->execute();
    $updateStmt->close();

    $conn->close();

    error_log("User logged in via face recognition: " . $user['email'] . " (Role: " . $user['role'] . ", distance: " . round($bestDistance, 4) . ")");

    echo json_encode([
        'success'  => true,
        'message'  => 'Login successful',
        'user'     => [
            'id'    => $user['id'],
            'name'  => $user['name'],
            'email' => $user['email'],
            'role'  => $user['role']
        ],
        'redirect' => '../bccsasqr/pages/dashboard.php'
    ]);

} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Login error occurred']);
    error_log("Face login error: " . $e->getMessage());
}
?>
