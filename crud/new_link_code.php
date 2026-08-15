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
if ($user_role === 'admin') {
    $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
    $own->bind_param("s", $old_code);
} else {
    $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ? AND instructor_id = ?");
    $own->bind_param("si", $old_code, $user_id);
}
$own->execute();

if ($own->get_result()->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to change.']);
    exit();
}

// ── Ang expiry ng BAGONG link ────────────────────────────────
// Walang hiniling na oras → NULL. Hindi minana ang luma: lumipas na
// iyon, kaya ipapanganak na patay ang bagong code.
$clause = link_expiry_clause($_POST, $conn);

if ($clause['error'] !== null) {
    echo json_encode(['success' => false, 'message' => $clause['error']]);
    exit();
}

$set    = $clause['sql'] ?? 'expires_at = NULL';
$types  = $clause['types'];
$params = $clause['params'];

// ── Palitan ──────────────────────────────────────────────────
// Kasama ang is_active = 1: maaaring pinatay ang link (manu-mano o
// dahil nawalan ng enrolled na estudyante), at ang paghingi ng
// bagong code ay malinaw na kahilingang buksang muli ito.
$new_code = link_generate_code($conn);

$stmt = $conn->prepare("
    UPDATE attendance_links_tbl
    SET short_code = ?, is_active = 1, $set
    WHERE short_code = ?
");
$stmt->bind_param('s' . $types . 's', ...array_merge([$new_code], $params, [$old_code]));

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Database error']);
    exit();
}

echo json_encode(array_merge(
    ['success' => true, 'old_code' => $old_code],
    link_state($conn, $new_code)
));

$conn->close();
