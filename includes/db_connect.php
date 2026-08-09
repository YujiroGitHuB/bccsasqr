<?php
// ============================================================
// Isang koneksyon lang kada request.
//
// Ang file na ito ay ini-include ng maraming lugar (dashboard.php,
// check_user_status.php, components/view_attendance.php, ...). Dahil
// `include` ito at hindi `include_once`, dating gumagawa ng BAGONG
// mysqli ang bawat pag-include — tatlong TCP + auth handshake kada
// page load ng dashboard.
//
// Sa remote database (sql108.infinityfree.com) ang connection setup
// ang pinakamahal na bahagi ng isang page — mas mahal pa kaysa sa
// mismong query. Isang beses na lang tayo kumakabit at ibinabahagi.
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

    // Itago para magamit muli ng susunod na include sa parehong request.
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