<?php
// TRUNCATEs the entire attendance table. It had no session check at
// all, so anyone who knew the URL could empty it — hence the admin
// guard, matching crud/delete_all_attendance.php.
session_start();
include("../includes/db_connect.php");
include __DIR__ . "/../includes/permissions.php";

if (!isAdmin()) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('admin: reset attendance');
    http_response_code(403);
    echo "unauthorized";
    exit;
}

$conn->query("TRUNCATE TABLE attendance_tbl");
$conn->close();
echo "cleared";
?>
