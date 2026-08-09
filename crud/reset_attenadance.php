<?php
include("../includes/db_connect.php");

$conn = new mysqli($host, $user, $pass, $db);
$conn->query("TRUNCATE TABLE attendance_tbl");
$conn->close();
echo "cleared";
?>
