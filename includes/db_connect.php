<?php
// ============================================================
// One connection per request.
//
// This file is included from many places (dashboard.php,
// check_user_status.php, components/view_attendance.php, ...). Because
// it is `include` and not `include_once`, every inclusion used to
// create a NEW mysqli — three TCP + auth handshakes per
// dashboard page load.
//
// Against a remote database (sql108.infinityfree.com) the connection
// setup is the most expensive part of a page — more expensive than
// the queries themselves. Now it connects once and shares.
// ============================================================
if (isset($GLOBALS['__bcc_conn']) && $GLOBALS['__bcc_conn'] instanceof mysqli) {
    $conn = $GLOBALS['__bcc_conn'];
    return;
}

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
ini_set('display_errors', 0);
error_reporting(0);

try {
    $conn = new mysqli(
        "localhost",
        "root",
        "",
        "bcc_qr_attendance_db"
    );

    if ($conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    //FIX: Support special characters like ñ, é, etc.
    $conn->set_charset("utf8mb4");

    // ── Ang orasan ng koneksyon ─────────────────────────────
    // Ang PHP ay nakatakda sa Asia/Manila (date_default_timezone_set),
    // pero ang NOW() ng MySQL ay sumusunod sa server — sa isang
    // shared host, karaniwang UTC. Walong oras ang pagitan, at
    // hanggang ngayon ay tahimik lang itong nagkakamali: ang
    // last_login, created_at at updated_at ay nakatatak sa maling
    // oras.
    //
    // Naging mahalaga ito nang magkaroon ng expiration ang
    // attendance links: kapag nag-type ang instructor ng "10:00 AM",
    // ang ibig niyang sabihin ay 10:00 AM sa Pilipinas, at ang
    // NOW() ang siyang magpapasya kung lumipas na ito.
    //
    // Numerong offset at hindi 'Asia/Manila': ang pangalan ay
    // nangangailangan ng mga time-zone table ng MySQL na madalas
    // walang laman sa shared hosting. Walang daylight saving ang
    // Pilipinas mula 1978, kaya +08:00 ang tama — palagi.
    @$conn->query("SET time_zone = '+08:00'");

    // Stash it so the next include in the same request reuses it.
    $GLOBALS['__bcc_conn'] = $conn;

} catch (Exception $e) {

    // LOG error
    error_log(
        date("Y-m-d H:i:s") . " | " . $e->getMessage() . PHP_EOL,
        3,
        __DIR__ . "/db_error.log"
    );

    // SHOW friendly error
    include __DIR__ . "/../error.php";
    exit;
}