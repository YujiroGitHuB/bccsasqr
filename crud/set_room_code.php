<?php
// ============================================================
// Buksan o isara ang code sa harapan para sa isang link.
//
// Kada link ang switch na ito, hindi pambuong sistema: may klaseng
// nasa isang silid na may projector, at may klaseng laboratoryo
// kung saan walang mapagsusulatan. Ang instruktor ang nakakaalam
// kung alin.
//
// Ang binhi ay ginagawa sa unang pagbukas at nananatili — kaya ang
// pagpatay at muling pagbukas ay hindi nagpapawalang-bisa sa
// kasalukuyang code. (Ang nagpapalit ng binhi ay ang bagong
// short_code sa crud/new_link_code.php: bagong session, bagong
// lahat.)
//
// Tinatanggap (POST):
//   short_code  kinakailangan
//   enabled     1 o 0
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
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to change.']);
    exit();
}

$enabled = (($_POST['enabled'] ?? '0') === '1') ? 1 : 0;

// Ang binhi bago ang switch: kapag naging 1 ang require_room_code
// habang NULL pa ang room_code_secret, ang bawat pagsusumite ay
// tatanggihan at walang code na maipapakita ang instruktor. Isang
// segundo lamang ang pagitan, pero sa isang segundong iyon ay nasa
// harap ng pintuan ang buong klase.
if ($enabled === 1 && room_code_secret($conn, $short_code) === null) {
    echo json_encode(['success' => false, 'message' => 'Could not prepare the room code. Please try again.']);
    exit();
}

$upd = $conn->prepare("UPDATE attendance_links_tbl SET require_room_code = ? WHERE short_code = ?");
$upd->bind_param("is", $enabled, $short_code);

if (!$upd->execute()) {
    echo json_encode(['success' => false, 'message' => 'Database error']);
    exit();
}

echo json_encode(['success' => true, 'enabled' => $enabled]);

$conn->close();
