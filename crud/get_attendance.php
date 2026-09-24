<?php
session_start();
include("../includes/db_connect.php");
require_once __DIR__ . "/../includes/late.php";

header('Content-Type: application/json');

if (!isset($_SESSION['user_id'])) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('sign-in');
    echo json_encode(["error" => "Not logged in"]);
    exit;
}

// Set timezone to Philippines
date_default_timezone_set('Asia/Manila');
$user_id = $_SESSION['user_id'];
$today = date('Y-m-d'); // Current PH date

// Fetch only this user's attendance for today
// is_late for the Late tag in the scanner's list, once the column exists.
$lateCol = late_ready($conn) ? 'is_late' : '0 AS is_late';

$sql = "SELECT date, student_no, name, course, section, subject, time_in, $lateCol
        FROM attendance_tbl 
        WHERE user_id = '$user_id' 
          AND DATE(date) = '$today'
        ORDER BY time_in DESC";

$result = $conn->query($sql);

$attendance = [];
while ($row = $result->fetch_assoc()) {
    $attendance[] = $row;
}

echo json_encode($attendance);
?>
