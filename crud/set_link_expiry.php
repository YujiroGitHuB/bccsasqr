<?php
// ============================================================
// Itakda, palawigin o alisin ang expiration ng isang attendance
// link — nang HINDI nagbabago ang short_code.
//
// Ito ang "Extend": kaparehong klase, kaparehong URL na hawak na ng
// mga estudyanteng nasa harap mo. Ang pagsisimula ng BAGONG session
// ay ibang tanong at nasa crud/new_link_code.php.
//
// Tinatanggap (POST):
//   short_code  kinakailangan
//   at saka ISA sa mga ito:
//     minutes=90     — mula ngayon
//     preset=eod     — hanggang 11:59:59 PM ngayong araw
//     at=2026-08-16T10:00  — mula sa datetime-local input
//     clear=1        — alisin ang expiry
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/links.php";

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

// ── Ang link ay dapat sa 'yo ─────────────────────────────────
// Ang admin ay nakakagalaw ng kahit anong link; ang instructor ay
// sa kanya lamang. (Ang deactivate_link.php ay wala pang ganitong
// tseke.)
if (!link_owned($conn, $short_code, $user_id, $user_role === 'admin')) {
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to change.']);
    exit();
}

// ── Ang bagong expiry ────────────────────────────────────────
$done = link_set_expiry($conn, $short_code, $_POST);

if ($done['error'] !== null) {
    echo json_encode(['success' => false, 'message' => $done['error']]);
    exit();
}

echo json_encode(array_merge(['success' => true], $done['state']));

$conn->close();
