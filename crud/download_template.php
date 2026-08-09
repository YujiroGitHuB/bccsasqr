<?php
session_start();

if (!isset($_SESSION['user_id'])) {
    header('Location: ../index.php');
    exit;
}

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