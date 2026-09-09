<?php
// ============================================================
// Ang live na anim na digit para sa isang klase.
//
// Ito ang ipinapakita ng instruktor sa projector o isinusulat sa
// pisara. Nagpapalit kada tatlumpung segundo, at hinihingi ng
// crud/submit_attendance.php sa mga link na binuksan ang tampok.
//
// Bakit hindi na lang ipadala ang binhi sa browser ng instruktor at
// doon kalkulahin: dahil ang orasan ng laptop sa harapan ay hindi
// palaging tama, at ang orasan ng server ang nagpapasya kung tama
// ang tinipa ng estudyante. Ilang segundong pagkakaiba lamang ay
// sapat na para ipakita ang code na tatanggihan naman. Ang server
// ang nagsasabi, at ang pahina ay muling nagtatanong kapag ubos na
// ang oras — isang tanong kada tatlumpung segundo, isang instruktor.
//
// Tinatanggap (POST):
//   short_code  kinakailangan
//
// Isinasauli:
//   code          ang kasalukuyang anim na digit
//   seconds_left  ilang segundo bago magpalit
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/links.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";

header('Content-Type: application/json');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit();
}

requirePermissionJson('links.manage');

$short_code = trim($_POST['short_code'] ?? '');
if ($short_code === '') {
    echo json_encode(['success' => false, 'message' => 'Short code required']);
    exit();
}

if (!link_owned_by($conn, $short_code, (int) $_SESSION['user_id'], $_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to open.']);
    exit();
}

$secret = room_code_secret($conn, $short_code);

if ($secret === null) {
    echo json_encode(['success' => false, 'message' => 'Link not found.']);
    exit();
}

$window = room_code_window();

echo json_encode([
    'success'      => true,
    'code'         => room_code_at($secret, $window),
    // Ang natitirang segundo sa kasalukuyang yugto. Hindi
    // ipinapadala ang susunod na code: ang pahinang may hawak ng
    // susunod ay pahinang may hawak ng hinaharap, at wala nang
    // dahilan para ilabas iyon ng server bago ang oras.
    'seconds_left' => INTEGRITY_ROOM_STEP - (time() % INTEGRITY_ROOM_STEP),
    'step'         => INTEGRITY_ROOM_STEP,
]);

$conn->close();
