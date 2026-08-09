<?php
header('Content-Type: application/json');
include __DIR__ . "/../includes/db_connect.php";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$student_no       = trim($_POST['student_no']       ?? '');
$subject_code     = trim($_POST['subject_code']     ?? '');
$required_section = trim($_POST['required_section'] ?? '');
$instructor_id    = trim($_POST['instructor_id']    ?? '');

if (empty($student_no)) {
    echo json_encode(['success' => false, 'message' => 'Student number is required']);
    exit;
}

try {
    // ── 1. Check if student exists ────────────────────────────────────────────
    $stmt = $conn->prepare("
        SELECT student_no, fullname, course, section 
        FROM students_tbl 
        WHERE TRIM(student_no) = ?
    ");
    $stmt->bind_param("s", $student_no);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Student number not found. Please check and try again.'
        ]);
        exit;
    }

    $student = $result->fetch_assoc();

    // Build full section e.g. "BSIT-2A" from students_tbl course + section
    $student['section'] = $student['course'] . '-' . $student['section'];

    // ── 2. Check if student is enrolled in this subject ───────────────────────
    if (!empty($subject_code)) {
        $enroll = $conn->prepare("
            SELECT section 
            FROM student_subjects_tbl
            WHERE TRIM(student_no) = ?
              AND UPPER(TRIM(subject_code)) = UPPER(TRIM(?))
            LIMIT 1
        ");
        $enroll->bind_param("ss", $student_no, $subject_code);
        $enroll->execute();
        $enroll_result = $enroll->get_result();

        if ($enroll_result->num_rows === 0) {
            echo json_encode([
                'success' => false,
                'message' => 'You are not enrolled in this subject.'
            ]);
            exit;
        }

        // ── 3. Check section from student_subjects_tbl (supports irreg students) ──
        $enrolled_row     = $enroll_result->fetch_assoc();
        $enrolled_section = strtoupper(trim($enrolled_row['section'])); // e.g. "2A"

        // Extract section part only from required_section (e.g. "BSIT-2A" → "2A")
        $req_parts        = explode('-', $required_section, 2);
        $req_section_only = strtoupper(trim($req_parts[1] ?? $required_section));

        if (!empty($required_section) && $enrolled_section !== $req_section_only) {
            echo json_encode([
                'success' => false,
                'message' => 'You are not in this section (' . htmlspecialchars($required_section) . ').'
            ]);
            exit;
        }
    }

    // ── 4. Check if instructor is assigned to this section ────────────────────
    if (!empty($instructor_id) && !empty($required_section)) {
        // required_section is "BSIT-2A", split to get course and section
        $parts     = explode('-', $required_section, 2); // ["BSIT", "2A"]
        $r_course  = $parts[0] ?? '';
        $r_section = $parts[1] ?? '';

        $instr = $conn->prepare("
            SELECT id FROM instructor_section_tbl
            WHERE instructor_id = ?
              AND UPPER(TRIM(course))  = UPPER(TRIM(?))
              AND UPPER(TRIM(section)) = UPPER(TRIM(?))
            LIMIT 1
        ");
        $instr->bind_param("iss", $instructor_id, $r_course, $r_section);
        $instr->execute();
        $instr_result = $instr->get_result();

        if ($instr_result->num_rows === 0) {
            echo json_encode([
                'success' => false,
                'message' => 'This attendance link is not valid for your section.'
            ]);
            exit;
        }
    }

    echo json_encode([
        'success' => true,
        'message' => 'Student found',
        'student' => $student
    ]);

    $stmt->close();

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error occurred'
    ]);
    error_log("Verify Student Error: " . $e->getMessage());
}

$conn->close();
?>