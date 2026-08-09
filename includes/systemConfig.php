<?php
include __DIR__ . "/../includes/db_connect.php";

// Get system configuration
$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);

$systemName = $system['system_name'] ?? 'None';
$systemLogo = $system['logo'] ?? 'assets/images/default-logo.png';
$systemAcronym = $system['system_acronym'] ?? 'None';
?>  