<?php
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