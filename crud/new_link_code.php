<?php
// ============================================================
// Bagong short_code para sa parehong klase.
//
// Ito ang sagot sa "bagong session", hindi sa "natagalan ang
// klase". Ang pagpapalawig lang ng oras ay hindi sapat kapag
// bagong araw na: nasa group chat na ang lumang URL, may screenshot
// na, at may nakalimbag nang QR. Kung ang susunod na klase ay
// gagamit ng parehong code, ang lahat ng minsang nakatanggap nito
// ay makakapag-scan kahit wala sila sa silid — na siya mismong
// pintong isinara ng expiry.
//
// UPDATE at hindi INSERT: nananatili sa isang hilera ang bawat
// (subject, section, instructor), gaya ng ginagawa na ng reuse
// logic sa pages/get_links_ajax.php. Sampung megabyte lang ang
// database, at ang bawat klase kada araw ay magiging libu-libong
// hilera sa loob ng isang semestre.
//
// Tinatanggap (POST):
//   short_code   kinakailangan — ang LUMANG code
//   minutes / preset / at   opsyonal; kung wala, walang expiry ang
//                           bagong link hanggang magtakda ka
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

$old_code = trim($_POST['short_code'] ?? '');
if ($old_code === '') {
    echo json_encode(['success' => false, 'message' => 'Short code required']);
    exit();
}

// ── Ang link ay dapat sa 'yo ─────────────────────────────────
if (!link_owned($conn, $old_code, $user_id, $user_role === 'admin')) {
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to change.']);
    exit();
}

// ── Palitan ──────────────────────────────────────────────────
// Ang expiry ng BAGONG link (kung may hiniling), ang pag-alis ng
// late cutoff at ang pagbubukas muli ay nasa link_renew() sa
// includes/links.php — ang app ay tumatawag din doon.
$done = link_renew($conn, $old_code, $_POST);

if ($done['error'] !== null) {
    echo json_encode(['success' => false, 'message' => $done['error']]);
    exit();
}

echo json_encode(array_merge(['success' => true], $done['state']));

$conn->close();
