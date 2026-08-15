<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";
date_default_timezone_set('Asia/Manila');
header('Content-Type: application/json');

// ── Check if form is locked ───────────────────────────────────────────────────
$result    = $conn->query("SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");
$is_locked = 0;
if ($result && $result->num_rows > 0) {
    $row       = $result->fetch_assoc();
    $is_locked = (int)$row['setting_value'];
}

if ($is_locked) {
    echo json_encode(['success' => false, 'message' => 'Attendance form is currently locked. Please contact your instructor.']);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit();
}

// ── Validate required fields ──────────────────────────────────────────────────
$required = ['student_no', 'short_code'];
foreach ($required as $field) {
    if (empty($_POST[$field])) {
        echo json_encode(['success' => false, 'message' => ucfirst(str_replace('_', ' ', $field)) . ' is required']);
        exit();
    }
}

$student_no = trim($_POST['student_no']);
$short_code = trim($_POST['short_code']);
$today      = date('Y-m-d');

// ── 0. Ang link ang nagsasabi kung anong klase ito ────────────────────────────
//
// Dati ay galing sa POST ang subject, section at instructor, at hindi
// tinitingnan ng file na ito ang link kahit kailan. Dalawang bagay ang
// naidudulot niyon:
//
//   1. Walang saysay ang deactivate. Ang estudyanteng nakabukas na ang
//      form ay makakapagsumite pa rin pagkatapos mong patayin ang link.
//   2. Hindi kailangan ng link. Sinumang minsang nakakita ng mga
//      halaga ay makakapag-POST nito nang diretso, magpakailanman.
//
// Ang expiration ay walang kabuluhan kung hindi ito sinusuri dito —
// kaya ang short_code na ang tanging pinagkakatiwalaan, at ang lahat
// ng iba pa ay binabasa mula sa hilera nito.
//
// Ang paghahambing ng oras ay nasa SQL: ang orasan ng database ang
// nagtakda ng expires_at (tingnan ang crud/set_link_expiry.php), kaya
// ang parehong orasan din ang dapat magsabing lumipas na ito.
$linkStmt = $conn->prepare("
    SELECT subject_id, subject_code, subject_name, section, instructor_id, instructor_name,
           is_active,
           (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired
    FROM attendance_links_tbl
    WHERE short_code = ?
");
$linkStmt->bind_param("s", $short_code);
$linkStmt->execute();
$linkResult = $linkStmt->get_result();

if ($linkResult->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'This attendance link is not valid.']);
    exit();
}

$link = $linkResult->fetch_assoc();

if ((int)$link['is_active'] !== 1) {
    echo json_encode(['success' => false, 'message' => 'This attendance link has been deactivated by your instructor.']);
    exit();
}

if ((int)$link['is_expired'] === 1) {
    echo json_encode(['success' => false, 'message' => 'This attendance link has already closed. Please ask your instructor for a new one.']);
    exit();
}

$subject_id      = $link['subject_id'];
$subject_code    = trim($link['subject_code']);
$subject_name    = trim($link['subject_name']);
$full_section    = trim($link['section']);   // "BSIT-1A"
$instructor_id   = (int)$link['instructor_id'];
$instructor_name = trim($link['instructor_name']);

// ── 1. Get student info from DB ───────────────────────────────────────────────
$stmt = $conn->prepare("SELECT student_no, fullname, course, section FROM students_tbl WHERE student_no = ?");
$stmt->bind_param("s", $student_no);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Student not found']);
    exit();
}
$student = $result->fetch_assoc();

// ── 2. Check enrollment ───────────────────────────────────────────────────────
$enroll = $conn->prepare("
    SELECT section 
    FROM student_subjects_tbl
    WHERE student_no   = ?
      AND subject_code = ?
    LIMIT 1
");
$enroll->bind_param("ss", $student_no, $subject_code);
$enroll->execute();
$enroll_result = $enroll->get_result();

if ($enroll_result->num_rows === 0) {
    echo json_encode([
        'success' => false,
        'message' => 'You are not enrolled in ' . $subject_name . '. Please contact your instructor.'
    ]);
    exit();
}

$enroll_data            = $enroll_result->fetch_assoc();
$enrolled_section_raw   = trim($enroll_data['section']); // could be "BSIT-1A" or "1A"

// ✅ KEY FIX: attendance_tbl stores course and section as SEPARATE columns
// students_tbl already has correct course (e.g. "BSIT")
// We must store section as raw "1A" — NOT "BSIT-1A"
$course = $student['course']; // "BSIT" from students_tbl — always correct

// Split section if it contains course prefix (e.g. "BSIT-1A" → "1A")
if (strpos($enrolled_section_raw, '-') !== false) {
    $parts           = explode('-', $enrolled_section_raw, 2);
    $section_to_save = trim($parts[1]); // "1A"
} else {
    $section_to_save = $enrolled_section_raw; // already raw "1A"
}

// ── 3. Check for duplicate attendance today ───────────────────────────────────
$dup = $conn->prepare("
    SELECT id FROM attendance_tbl 
    WHERE student_no = ? AND date = ? AND subject = ?
    LIMIT 1
");
$dup->bind_param("sss", $student_no, $today, $subject_name);
$dup->execute();

if ($dup->get_result()->num_rows > 0) {
    echo json_encode([
        'success' => false,
        'message' => 'You have already submitted your attendance for ' . $subject_name . ' today.'
    ]);
    exit();
}

// ── 4. Insert attendance record ───────────────────────────────────────────────
// ✅ course = "BSIT", section = "1A" — stored separately so all queries match
$time_in = date('h:i:s A');
$name    = $student['fullname'];

$insert = $conn->prepare("
    INSERT INTO attendance_tbl 
        (date, student_no, name, course, section, subject, instructor, time_in, user_id) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
");
$insert->bind_param(
    "ssssssssi",
    $today,
    $student_no,
    $name,
    $course,           // "BSIT"  ← from students_tbl
    $section_to_save,  // "1A"    ← split from enrollment section
    $subject_name,
    $instructor_name,
    $time_in,
    $instructor_id
);

if ($insert->execute()) {
    echo json_encode(['success' => true, 'message' => 'Attendance submitted successfully for ' . $subject_name . '!']);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to submit attendance. Please try again.']);
}

$insert->close();
$conn->close();