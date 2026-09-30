<?php
ob_start();

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/links.php";

ob_clean();
header('Content-Type: application/json');

requirePermissionJson('links.manage');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$user_id   = (int) $_SESSION['user_id'];
$user_role = $_SESSION['role'];

// ─── Cache ────────────────────────────────────────────────────────────────────
$cache_key = 'attendance_links_' . $user_id;
$cache_ttl = 600;

if (
    !isset($_GET['refresh']) &&
    isset($_SESSION[$cache_key]) &&
    (time() - $_SESSION[$cache_key]['time']) < $cache_ttl
) {
    // Ang mabigat na JOIN ang naka-cache — HINDI ang expiry. Sampung
    // minuto ang TTL, at ang link na may isang oras na buhay ay
    // magpapakita ng maling countdown sa buong panahong iyon (o
    // magmumukhang buhay pa gayong patay na). Isang magaan na tanong
    // ang nagpapasariwa nito.
    $cached = links_attach_state($conn, $_SESSION[$cache_key]['data']);
    echo json_encode(['success' => true, 'cached' => true, 'data' => $cached]);
    exit;
}

// ─── The list ─────────────────────────────────────────────────────────────────
// Which links exist, and the upkeep that comes with asking (deactivating
// links whose class is empty, renewing ones that expired on an earlier
// day), is links_for_user() in includes/links.php — the phone app's
// Links tab asks the same function.
try {
    $result = links_for_user($conn, $user_id, $user_role);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'DB error: ' . $e->getMessage()]);
    exit;
}

$protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http";
$host     = $_SERVER['HTTP_HOST'];
$base_dir = str_replace('/admin', '', dirname($_SERVER['PHP_SELF']));

$links = [];
foreach ($result['links'] as $l) {
    $l['link'] = $protocol . "://" . $host . $base_dir . "/daily_attendance.php?c=" . $l['short_code'];
    $links[]   = $l;
}

// ─── Cache + respond ──────────────────────────────────────────────────────────
// Naka-cache ang listahan nang WALANG expiry; idinidikit ito sa
// bawat sagot (tingnan ang links_attach_state), kaya hindi kailanman
// naipupundar ang isang lumang countdown sa session.
$_SESSION[$cache_key] = ['data' => $links, 'time' => time()];

echo json_encode([
    'success' => true,
    'cached'  => false,
    'data'    => links_attach_state($conn, $links),
    // Para masabi ng pahina kung ilang link ang binigyan ng bagong
    // code habang wala ka — kung hindi, tahimik na magbabago ang mga
    // URL at magtataka ka kung bakit patay na ang ipinadala mo kahapon.
    'rotated' => $result['rotated'],
]);
