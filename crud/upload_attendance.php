<?php
session_start();
include "../includes/db_connect.php";
include "../includes/auth.php";

header('Content-Type: application/json');
date_default_timezone_set('Asia/Manila');

if ($_SERVER['REQUEST_METHOD'] != 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$user_id = $_SESSION['user_id'];
$subject_id = $_POST['subject_id'] ?? '';
$attendance_date = $_POST['attendance_date'] ?? '';
$time_in = $_POST['time_in'] ?? '';

// Convert to 12-hour format with AM/PM
if (!empty($time_in)) {
    $time_in = date('h:i:s A', strtotime($time_in));
}

// Validate inputs
if (empty($subject_id) || empty($attendance_date) || empty($time_in)) {
    echo json_encode(['success' => false, 'message' => 'Missing required fields']);
    exit;
}

// Get subject details
$subject_stmt = $conn->prepare("SELECT subject_code, subject_name FROM subjects_tbl WHERE id = ?");
$subject_stmt->bind_param("i", $subject_id);
$subject_stmt->execute();
$subject_result = $subject_stmt->get_result();

if ($subject_result->num_rows == 0) {
    echo json_encode(['success' => false, 'message' => 'Invalid subject']);
    exit;
}

$subject_data = $subject_result->fetch_assoc();
$subject_name = $subject_data['subject_name'];
$subject_code = $subject_data['subject_code'];

// Get instructor's assigned sections
$sections_stmt = $conn->prepare("SELECT section FROM instructor_section_tbl WHERE instructor_id = ?");
$sections_stmt->bind_param("i", $user_id);
$sections_stmt->execute();
$sections_result = $sections_stmt->get_result();

$allowed_sections = [];
while ($row = $sections_result->fetch_assoc()) {
    $allowed_sections[] = $row['section'];
}

if (empty($allowed_sections)) {
    echo json_encode([
        'success' => false, 
        'message' => 'You have no assigned sections. Please contact admin.'
    ]);
    exit;
}

// Validate CSV file
if (!isset($_FILES['csv_file']) || $_FILES['csv_file']['error'] != 0) {
    echo json_encode(['success' => false, 'message' => 'No file uploaded or upload error']);
    exit;
}

$file = $_FILES['csv_file']['tmp_name'];
$handle = fopen($file, 'r');

if (!$handle) {
    echo json_encode(['success' => false, 'message' => 'Could not open CSV file']);
    exit;
}

$errors = [];
$matched = 0;
$skipped = 0;
$not_found = 0;
$not_authorized = 0; // NEW: For students not in instructor's sections

$skipped_students = [];
$not_found_students = [];
$not_authorized_students = []; // NEW

// Skip header row
fgetcsv($handle);

// Prepare statements
$check_student_stmt = $conn->prepare("
    SELECT s.student_no, s.fullname, s.course, s.section 
    FROM students_tbl s
    WHERE s.student_no = ?
");

$check_duplicate_stmt = $conn->prepare("
    SELECT id FROM attendance_tbl 
    WHERE student_no = ? 
    AND subject = ? 
    AND DATE(date) = ?
");

$insert_stmt = $conn->prepare("
    INSERT INTO attendance_tbl 
    (user_id, student_no, name, course, section, subject, date, time_in) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
");

while (($data = fgetcsv($handle)) !== FALSE) {
    if (empty($data[0])) continue;
    
    $student_no = trim($data[0]);
    
    // Check if student exists
    $check_student_stmt->bind_param("s", $student_no);
    $check_student_stmt->execute();
    $student_result = $check_student_stmt->get_result();
    
    if ($student_result->num_rows == 0) {
        $not_found++;
        $not_found_students[] = $student_no;
        continue;
    }
    
    $student = $student_result->fetch_assoc();
    
    // NEW: Validate if student's section is in instructor's assigned sections
    if (!in_array($student['section'], $allowed_sections)) {
        $not_authorized++;
        $not_authorized_students[] = $student_no . ' (' . $student['fullname'] . ' - Section ' . $student['section'] . ')';
        continue;
    }
    
    // Check if already recorded for this subject on this date
    $check_duplicate_stmt->bind_param("sss", $student_no, $subject_name, $attendance_date);
    $check_duplicate_stmt->execute();
    $duplicate_result = $check_duplicate_stmt->get_result();
    
    if ($duplicate_result->num_rows > 0) {
        $skipped++;
        $skipped_students[] = $student_no . ' (' . $student['fullname'] . ')';
        continue;
    }
    
    // Insert attendance record
    $datetime = $attendance_date . ' ' . $time_in;
    
    $insert_stmt->bind_param(
        "isssssss",
        $user_id,
        $student_no,
        $student['fullname'],
        $student['course'],
        $student['section'],
        $subject_name,
        $datetime,
        $time_in
    );
    
    if ($insert_stmt->execute()) {
        $matched++;
    } else {
        $errors[] = "Failed to insert: $student_no - " . $conn->error;
    }
}

fclose($handle);

echo json_encode([
    'success' => true,
    'message' => "Imported $matched attendance records for $subject_name",
    'matched' => $matched,
    'skipped' => $skipped,
    'not_found' => $not_found,
    'not_authorized' => $not_authorized,
    'errors' => $errors,
    'skipped_students' => $skipped_students,
    'not_found_students' => $not_found_students,
    'not_authorized_students' => $not_authorized_students
]);
?>