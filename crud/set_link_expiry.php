<?php
// ============================================================
// Itakda, palawigin o alisin ang expiration ng isang attendance
// link.
//
// Lahat ng oras ay galing sa NOW() ng database at hindi sa PHP:
// tatlo sa apat na file na humahawak ng links ang walang
// date_default_timezone_set, kaya ang PHP na kalkulasyon ay
// magkakaiba nang ilang oras depende sa kung aling file ang
// nagtanong. Isang orasan lang — ang sa database.
//
// Tinatanggap (POST):
//   short_code  kinakailangan
//   at saka ISA sa mga ito:
//     minutes=90     — mula ngayon
//     preset=eod     — hanggang 11:59:59 PM ngayong araw
//     at=2026-08-16T10:00  — mula sa datetime-local input
//     clear=1        — alisin ang expiry (babalik sa walang hanggan)
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
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
// tseke — tingnan ang tala sa dulo ng file na ito.)
if ($user_role === 'admin') {
    $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
    $own->bind_param("s", $short_code);
} else {
    $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ? AND instructor_id = ?");
    $own->bind_param("si", $short_code, $user_id);
}
$own->execute();

if ($own->get_result()->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Link not found, or it is not yours to change.']);
    exit();
}

// ── Bumuo ng SET clause ──────────────────────────────────────
// Ang expiry ay laging kinakalkula SA LOOB ng SQL, kaya walang
// pagkakataong makapasok ang orasan ng PHP.
$sql       = null;
$types     = '';
$params    = [];
$custom_at = null;   // nakatakda lang sa sangang "at"

if (!empty($_POST['clear'])) {
    $sql = "UPDATE attendance_links_tbl SET expires_at = NULL WHERE short_code = ?";

} elseif (($_POST['preset'] ?? '') === 'eod') {
    // Hanggang katapusan ng araw NGAYON. Hindi "+24 oras": ang
    // hinihingi ay "hanggang matapos ang araw na ito".
    $sql = "UPDATE attendance_links_tbl
            SET expires_at = TIMESTAMP(CURDATE(), '23:59:59')
            WHERE short_code = ?";

} elseif (isset($_POST['minutes'])) {
    $minutes = (int) $_POST['minutes'];

    // 1 minuto hanggang 7 araw. Ang link na tatagal nang mahigit
    // isang linggo ay walang pinagkaiba sa walang expiry.
    if ($minutes < 1 || $minutes > 10080) {
        echo json_encode(['success' => false, 'message' => 'Duration must be between 1 minute and 7 days.']);
        exit();
    }

    $sql    = "UPDATE attendance_links_tbl
               SET expires_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)
               WHERE short_code = ?";
    $types  = 'i';
    $params = [$minutes];

} elseif (isset($_POST['at'])) {
    // Galing sa <input type="datetime-local">: "2026-08-16T10:00".
    $raw = trim($_POST['at']);
    $dt  = DateTime::createFromFormat('Y-m-d\TH:i', $raw)
        ?: DateTime::createFromFormat('Y-m-d\TH:i:s', $raw);

    if (!$dt) {
        echo json_encode(['success' => false, 'message' => 'Invalid date and time.']);
        exit();
    }

    // Ang hinaharap lang ang may saysay. Ang paghahambing ay sa
    // SQL pa rin (NOW()), kaya walang time-zone na pagkakamali —
    // tinatanggihan ng WHERE ang nakaraan at nagiging 0 ang
    // affected rows.
    $custom_at = $dt->format('Y-m-d H:i:s');

    // Ang hinaharap lang ang may saysay — at ang database pa rin ang
    // nagsasabi kung ano ang "ngayon". Hiwalay na tanong ito at hindi
    // isinama sa WHERE ng UPDATE: kapag pareho ang bagong petsa sa
    // luma, zero ang affected_rows ng MySQL, at hindi na
    // mapagkakaiba ang "walang binago" sa "lumipas na".
    $chk = $conn->prepare("SELECT (? > NOW()) AS ok");
    $chk->bind_param("s", $custom_at);
    $chk->execute();

    if ((int) $chk->get_result()->fetch_assoc()['ok'] !== 1) {
        echo json_encode(['success' => false, 'message' => 'That time has already passed.']);
        exit();
    }

    $sql    = "UPDATE attendance_links_tbl SET expires_at = ? WHERE short_code = ?";
    $types  = 's';
    $params = [$custom_at];

} else {
    echo json_encode(['success' => false, 'message' => 'Nothing to set.']);
    exit();
}

// Ang short_code ang laging huling placeholder (ang WHERE).
$types   .= 's';
$params[] = $short_code;

$stmt = $conn->prepare($sql);
if ($types !== '') {
    $stmt->bind_param($types, ...$params);
}

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Database error']);
    exit();
}

// ── Ibalik ang BAGONG kalagayan, galing sa database ──────────
// Hindi ang kinalkula ng PHP: ang mismong halagang susuriin ng
// daily_attendance.php at submit_attendance.php mamaya ang
// ibinabalik dito, kaya hindi mag-iiba ang ipinapakita ng card sa
// aktuwal na tatanggapin ng server.
$fresh = $conn->prepare("
    SELECT expires_at,
           (expires_at IS NOT NULL AND expires_at <= NOW())      AS is_expired,
           TIMESTAMPDIFF(SECOND, NOW(), expires_at)              AS expires_in,
           DATE_FORMAT(expires_at, '%b %e, %Y %l:%i %p')         AS expires_label
    FROM attendance_links_tbl
    WHERE short_code = ?
");
$fresh->bind_param("s", $short_code);
$fresh->execute();
$row = $fresh->get_result()->fetch_assoc();

echo json_encode([
    'success'       => true,
    'short_code'    => $short_code,
    'expires_at'    => $row['expires_at'],
    'expires_label' => $row['expires_label'],
    'expires_in'    => $row['expires_in'] === null ? null : (int) $row['expires_in'],
    'is_expired'    => (int) $row['is_expired'] === 1,
]);

$conn->close();
