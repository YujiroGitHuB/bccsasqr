<?php
// ============================================================
// "Tiningnan ko na ito."
//
// Ang pages/attendance_integrity.php ay nagpapakita ng mga hilerang
// nangangailangan ng tao — at ang tao ang tanging nakakaalam kung
// ang isang hiniram na telepono ay hiniram nga. Kung walang
// paglalagyan ng sagot na iyon, ang parehong anim na hilera ay
// muling sinusuri kada linggo, at ang bagong hilera ay nalulunod sa
// mga lumang nasagot na.
//
// Tinatanggap (POST):
//   id     ang audit row — kinakailangan
//   note   ang dahilan, hanggang 255 karakter — opsyonal
//   undo   1 = bawiin ang pagsusuri, ibalik sa hindi pa natitingnan
//
// Ibinabalik ang bagong kalagayan ng hilera, kaya hindi kailangang
// mag-reload ng pahina para lang makita ang sarili mong pagpindot.
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');
date_default_timezone_set('Asia/Manila');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit();
}

// Kaparehong susi ng pahinang tumatawag nito. Ang nakakabasa ng
// talaan ang siya ring nakakasagot dito — walang saysay ang isa
// kung wala ang isa.
requirePermissionJson('links.manage');

$user_id  = (int) $_SESSION['user_id'];
$is_admin = ($_SESSION['role'] === 'admin');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit();
}

$id = (int) ($_POST['id'] ?? 0);
if ($id <= 0) {
    echo json_encode(['success' => false, 'message' => 'Row required']);
    exit();
}

$undo = ($_POST['undo'] ?? '') === '1';
$note = trim((string) ($_POST['note'] ?? ''));

// 255 ang column. Pinuputol dito at hindi sa database: ang tahimik
// na pagkaputol ng huling salita ng isang tala ay mas masahol kaysa
// sa isang tala na alam mong maikli.
if (function_exists('mb_substr')) {
    $note = mb_substr($note, 0, 255);
} else {
    $note = substr($note, 0, 255);
}

// ── Sa iyo ba ang hilerang ito? ──────────────────────────────
//
// Ang admin ay nakakagalaw ng lahat; ang instructor ay ang sarili
// niyang klase lamang — kaparehong hangganan ng pahina mismo, at
// kailangang naririto rin ito: ang pagpindot ay POST na kayang
// gawin nang diretso, at walang sinasabi ang pahina tungkol sa
// kung ano ang ipinapadala nito.
//
// Ang hilerang NULL ang instructor_id (isang bad_link, halimbawa —
// hindi pa nababasa ang klase noong ito ay isinulat) ay walang
// may-ari, kaya admin lamang ang makakasagot doon.
try {
    $own = $conn->prepare("SELECT instructor_id FROM attendance_audit_tbl WHERE id = ? LIMIT 1");
    $own->bind_param("i", $id);
    $own->execute();
    $row = $own->get_result()->fetch_assoc();
    $own->close();
} catch (Throwable $e) {
    error_log('review_audit: ' . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => 'The integrity log is not set up yet. Run migrations/2026-09-10_add_audit_review.sql.'
    ]);
    exit();
}

if (!$row) {
    echo json_encode(['success' => false, 'message' => 'That row is gone. The log keeps 30 days.']);
    exit();
}

if (!$is_admin && (int) ($row['instructor_id'] ?? 0) !== $user_id) {
    echo json_encode(['success' => false, 'message' => 'That submission belongs to another instructor.']);
    exit();
}

// ── Ang pagsulat ─────────────────────────────────────────────
try {
    if ($undo) {
        // Tinatanggal pati ang tala: ang "hindi pa natitingnan" na
        // may nakasulat na dahilan ay dalawang bagay na
        // magkasalungat sa iisang hilera.
        $stmt = $conn->prepare("
            UPDATE attendance_audit_tbl
            SET reviewed_at = NULL, reviewed_by = NULL, note = NULL
            WHERE id = ?
        ");
        $stmt->bind_param("i", $id);
    } else {
        $noteVal = ($note === '') ? null : $note;
        $stmt = $conn->prepare("
            UPDATE attendance_audit_tbl
            SET reviewed_at = NOW(), reviewed_by = ?, note = ?
            WHERE id = ?
        ");
        $stmt->bind_param("isi", $user_id, $noteVal, $id);
    }

    $stmt->execute();
    $stmt->close();
} catch (Throwable $e) {
    error_log('review_audit: ' . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => 'Could not save. The review columns may be missing — run migrations/2026-09-10_add_audit_review.sql.'
    ]);
    exit();
}

// Ang pangalan ng sumuri, para sa hilerang ipinapakita agad.
$who = '';
if (!$undo) {
    try {
        $u = $conn->prepare("SELECT name FROM users WHERE id = ? LIMIT 1");
        $u->bind_param("i", $user_id);
        $u->execute();
        $who = (string) ($u->get_result()->fetch_assoc()['name'] ?? '');
        $u->close();
    } catch (Throwable $e) {
        // Ang pangalan ay palamuti. Ang pagsusuri ay naisulat na.
        error_log('review_audit (name): ' . $e->getMessage());
    }
}

echo json_encode([
    'success'  => true,
    'reviewed' => !$undo,
    'note'     => $undo ? '' : $note,
    'by'       => $who,
    'at'       => $undo ? '' : date('M j, g:i A'),
]);
