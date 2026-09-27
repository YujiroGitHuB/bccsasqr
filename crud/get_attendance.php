<?php
session_start();
include("../includes/db_connect.php");
require_once __DIR__ . "/../includes/scan_attendance.php";

header('Content-Type: application/json');

if (!isset($_SESSION['user_id'])) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('sign-in');
    echo json_encode(["error" => "Not logged in"]);
    exit;
}

// Only this user's attendance for today (Philippine date), newest
// first — the same list the phone app's scanner shows. is_late rides
// along for the Late tag in the scanner's list.
echo json_encode(scan_today($conn, (int) $_SESSION['user_id']));
