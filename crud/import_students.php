<?php
session_start();
include "../includes/auth.php";
include "../includes/db_connect.php";

header('Content-Type: application/json');
$conn->set_charset("utf8mb4");

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method.']);
    exit;
}

if (!isset($_FILES['csv_file']) || $_FILES['csv_file']['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(['success' => false, 'message' => 'No file uploaded or upload error.']);
    exit;
}

$file     = $_FILES['csv_file']['tmp_name'];
$fileType = $_POST['file_type'] ?? 'csv';       // 'csv' or 'xls'
$course   = trim($_POST['course']   ?? '');
$section  = trim($_POST['section']  ?? '');
$imported = 0;
$skipped  = 0;
$errors   = [];
$user_id  = $_SESSION['user_id'];

// ========== HELPER: convert value to UTF-8 ==========
function toUtf8(string $value, string $fromEncoding): string {
    $value = trim($value);
    if ($fromEncoding !== 'UTF-8') {
        return mb_convert_encoding($value, 'UTF-8', $fromEncoding);
    }
    return $value;
}

// ========== HELPER: insert one student ==========
function insertStudent($conn, $student_no, $fullname, $course, $section, $user_id, $rowNumber, &$imported, &$skipped, &$errors) {
    if (empty($student_no) || empty($fullname) || empty($course) || empty($section)) {
        $errors[] = "Row $rowNumber: Missing required fields, skipped.";
        $skipped++;
        return;
    }

    // Check duplicate
    $check = $conn->prepare("SELECT id FROM students_tbl WHERE student_no = ?");
    $check->bind_param("s", $student_no);
    $check->execute();
    $check->store_result();
    if ($check->num_rows > 0) {
        $errors[] = "Row $rowNumber: Student No. '$student_no' already exists, skipped.";
        $check->close();
        $skipped++;
        return;
    }
    $check->close();

    $stmt = $conn->prepare(
        "INSERT INTO students_tbl (student_no, fullname, course, section, user_id) VALUES (?, ?, ?, ?, ?)"
    );
    $stmt->bind_param("ssssi", $student_no, $fullname, $course, $section, $user_id);
    if ($stmt->execute()) {
        $imported++;
    } else {
        $errors[] = "Row $rowNumber: DB error — " . $stmt->error;
        $skipped++;
    }
    $stmt->close();
}

// ========================================
// MODE A: XLS (tab-separated, from school grading system)
// Columns: No. | Student Number | Student Name | (empty)
// Course & Section come from POST fields
// ========================================
if ($fileType === 'xls') {

    if (empty($course) || empty($section)) {
        echo json_encode(['success' => false, 'message' => 'Course and Section are required for XLS import.']);
        exit;
    }

    if (($handle = fopen($file, 'rb')) === false) {
        echo json_encode(['success' => false, 'message' => 'Could not open the file.']);
        exit;
    }

    // Detect encoding from sample
    $sample      = fread($handle, 2000);
    rewind($handle);
    $fileEncoding = mb_detect_encoding($sample, ['UTF-8', 'Windows-1252', 'ISO-8859-1'], true) ?: 'Windows-1252';

    $rowNumber = 0;
    while (($row = fgetcsv($handle, 1000, "\t")) !== false) {
        $rowNumber++;

        // Skip header row (No. | Student Number | Student Name)
        if ($rowNumber === 1) continue;

        // Skip empty rows
        if (empty(array_filter($row))) continue;

        // Expect at least 3 columns: No., Student Number, Student Name
        if (count($row) < 3) {
            $errors[] = "Row $rowNumber: Not enough columns, skipped.";
            $skipped++;
            continue;
        }

        // Col 0 = No. (skip), Col 1 = Student Number, Col 2 = Student Name
        $student_no = toUtf8($row[1], $fileEncoding);
        $fullname   = toUtf8($row[2], $fileEncoding);
        // Course & Section from POST
        $rowCourse  = toUtf8($course,  'UTF-8');
        $rowSection = toUtf8($section, 'UTF-8');

        insertStudent($conn, $student_no, $fullname, $rowCourse, $rowSection, $user_id, $rowNumber, $imported, $skipped, $errors);
    }

    fclose($handle);

// ========================================
// MODE B: CSV (standard format)
// Columns: student_no, fullname, course, section
// Course & Section from the CSV row itself
// (POST course/section used as fallback if CSV cols are empty)
// ========================================
} else {

    if (($handle = fopen($file, 'rb')) === false) {
        echo json_encode(['success' => false, 'message' => 'Could not open the CSV file.']);
        exit;
    }

    // Strip BOM if present
    $bom = fread($handle, 3);
    if ($bom !== "\xEF\xBB\xBF") {
        rewind($handle);
    }

    // Detect encoding
    $sample       = fread($handle, 2000);
    rewind($handle);
    $checkBom     = fread($handle, 3);
    if ($checkBom !== "\xEF\xBB\xBF") rewind($handle);
    $fileEncoding = mb_detect_encoding($sample, ['UTF-8', 'Windows-1252', 'ISO-8859-1'], true) ?: 'Windows-1252';

    $rowNumber = 0;
    while (($row = fgetcsv($handle, 1000, ',')) !== false) {
        $rowNumber++;

        if ($rowNumber === 1) continue; // skip header
        if (empty(array_filter($row))) continue;

        if (count($row) < 4) {
            $errors[] = "Row $rowNumber: Not enough columns, skipped.";
            $skipped++;
            continue;
        }

        $student_no = toUtf8($row[0], $fileEncoding);
        $fullname   = toUtf8($row[1], $fileEncoding);
        $rowCourse  = toUtf8($row[2], $fileEncoding) ?: $course;
        $rowSection = toUtf8($row[3], $fileEncoding) ?: $section;

        insertStudent($conn, $student_no, $fullname, $rowCourse, $rowSection, $user_id, $rowNumber, $imported, $skipped, $errors);
    }

    fclose($handle);
}

echo json_encode([
    'success'  => true,
    'message'  => "Import complete. $imported student(s) added.",
    'imported' => $imported,
    'skipped'  => $skipped,
    'errors'   => $errors
]);