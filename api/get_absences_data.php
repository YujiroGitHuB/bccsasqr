<?php
/**
 * API: Get Absences Data
 * Returns list of students with specified minimum absences
 */

session_start();
include __DIR__ . "/../includes/db_connect.php";

if (!isset($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$user_id      = $_SESSION['user_id'];
$role         = $_SESSION['role'];

$full_section = isset($_POST['section'])      ? $_POST['section']      : '';
$min_absences = isset($_POST['min_absences']) ? (int)$_POST['min_absences'] : 3;

if (empty($full_section)) {
    echo json_encode(['success' => false, 'message' => 'Section is required']);
    exit;
}

// ✅ FIXED: split "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = $conn->real_escape_string($parts[0] ?? '');
$section = $conn->real_escape_string($parts[1] ?? $full_section);

// ── Access check (instructor only) ───────────────────────
if ($role !== 'admin') {
    // ✅ FIXED: check both course AND section
    $check_stmt = $conn->prepare("
        SELECT COUNT(*) as cnt
        FROM instructor_section_tbl
        WHERE instructor_id = ? AND course = ? AND section = ?
    ");
    $check_stmt->bind_param("iss", $user_id, $course, $section);
    $check_stmt->execute();
    $has_access = $check_stmt->get_result()->fetch_assoc()['cnt'] > 0;

    if (!$has_access) {
        echo json_encode(['success' => false, 'message' => 'Access denied']);
        exit;
    }
}

// ── Subject filter (instructor only) ────────────────────
$subjects_filter = "";
if ($role !== 'admin') {
    $subjects_query = $conn->prepare("
        SELECT s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        WHERE si.instructor_id = ?
    ");
    $subjects_query->bind_param("i", $user_id);
    $subjects_query->execute();
    $result = $subjects_query->get_result();

    $subject_names = [];
    while ($row = $result->fetch_assoc()) {
        $subject_names[] = "'" . $conn->real_escape_string($row['subject_name']) . "'";
    }

    if (!empty($subject_names)) {
        $subjects_filter = "AND subject IN (" . implode(',', $subject_names) . ")";
    }
}

// ── Total unique class dates for this section ─────────────
// ✅ FIXED: attendance_tbl has separate course + section columns
if ($role === 'admin') {
    $stmt = $conn->prepare("
        SELECT COUNT(DISTINCT DATE(date)) as total_classes
        FROM attendance_tbl
        WHERE course = ? AND section = ?
    ");
    $stmt->bind_param("ss", $course, $section);
} else {
    $stmt = $conn->prepare("
        SELECT COUNT(DISTINCT DATE(date)) as total_classes
        FROM attendance_tbl
        WHERE course = ? AND section = ?
        $subjects_filter
    ");
    $stmt->bind_param("ss", $course, $section);
}
$stmt->execute();
$total_classes = (int)$stmt->get_result()->fetch_assoc()['total_classes'];

// ── Students with absences >= min_absences ────────────────
// ✅ FIXED: all WHERE clauses use both course + section
if ($role === 'admin') {
    $students_query = "
        SELECT
            s.student_no,
            s.fullname,
            s.course,
            COALESCE(a.attended, 0)             AS attended,
            $total_classes                       AS total_classes,
            ($total_classes - COALESCE(a.attended, 0)) AS absences
        FROM students_tbl s
        LEFT JOIN (
            SELECT student_no, COUNT(DISTINCT DATE(date)) AS attended
            FROM attendance_tbl
            WHERE course = '$course' AND section = '$section'
            GROUP BY student_no
        ) a ON s.student_no = a.student_no
        WHERE s.course = '$course' AND s.section = '$section'
        HAVING absences >= ?
        ORDER BY absences DESC, s.fullname ASC
    ";
    $stmt = $conn->prepare($students_query);
    $stmt->bind_param("i", $min_absences);
} else {
    $students_query = "
        SELECT
            s.student_no,
            s.fullname,
            s.course,
            COALESCE(a.attended, 0)             AS attended,
            $total_classes                       AS total_classes,
            ($total_classes - COALESCE(a.attended, 0)) AS absences
        FROM students_tbl s
        LEFT JOIN (
            SELECT student_no, COUNT(DISTINCT DATE(date)) AS attended
            FROM attendance_tbl
            WHERE course = '$course' AND section = '$section'
            $subjects_filter
            GROUP BY student_no
        ) a ON s.student_no = a.student_no
        WHERE s.course = '$course' AND s.section = '$section'
        HAVING absences >= ?
        ORDER BY absences DESC, s.fullname ASC
    ";
    $stmt = $conn->prepare($students_query);
    $stmt->bind_param("i", $min_absences);
}

$stmt->execute();
$result = $stmt->get_result();

$students = [];
while ($row = $result->fetch_assoc()) {
    $students[] = [
        'student_no'    => $row['student_no'],
        'name'          => $row['fullname'],
        'course'        => $row['course'],
        'attended'      => (int)$row['attended'],
        'total_classes' => (int)$row['total_classes'],
        'absences'      => (int)$row['absences'],
    ];
}

echo json_encode([
    'success'       => true,
    'students'      => $students,
    'total_classes' => $total_classes,
    'section'       => $full_section,   // return full "BSIT-1A" for the frontend
    'min_absences'  => $min_absences,
]);