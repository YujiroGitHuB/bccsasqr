<?php
session_start();
include("../includes/db_connect.php");

header('Content-Type: application/json');

if (!isset($_SESSION['user_id'])) {
    echo json_encode(["error" => "Not logged in"]);
    exit;
}

// Set timezone to Philippines
date_default_timezone_set('Asia/Manila');
$user_id = $_SESSION['user_id'];
$today = date('Y-m-d'); // Current PH date

// Fetch only this user's attendance for today
$sql = "SELECT date, student_no, name, course, section, subject, time_in 
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
