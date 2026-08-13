<?php
session_start();

if (!isset($_SESSION['user_id'])) {
    header('Location: ../index.php');
    exit;
}

// This is the ATTENDANCE import template ("attendance_template.csv", a
// student_no column) — assets/js/upload_attendance.js is its only
// caller, not the student importer. So it rides on attendance.import
// rather than being open to anyone with a login.
include __DIR__ . "/../includes/permissions.php";
requirePermission('attendance.import', '../pages/dashboard.php');

// Set headers for CSV download
header('Content-Type: text/csv');
header('Content-Disposition: attachment; filename="attendance_template.csv"');

// Open output stream
$output = fopen('php://output', 'w');

// Write header only
fputcsv($output, ['student_no']);

// Add sample data (optional - for reference)
fputcsv($output, ['019-464']);

fclose($output);
exit;
?>