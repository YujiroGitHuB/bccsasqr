<?php
session_start();
header('Content-Type: application/json');
include __DIR__ . "/../includes/db_connect.php";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$full_section     = trim($_POST['section']          ?? '');
$facilitator_id   = trim($_POST['facilitator_id']   ?? '');
$facilitator_role = trim($_POST['facilitator_role'] ?? '');

if (empty($full_section)) {
    echo json_encode(['success' => false, 'message' => 'Section is required']);
    exit;
}

if (empty($facilitator_id) || empty($facilitator_role)) {
    echo json_encode(['success' => false, 'message' => 'Facilitator information is required']);
    exit;
}

// ✅ FIXED: split "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = $parts[0] ?? '';
$section = $parts[1] ?? $full_section;

try {
    if ($facilitator_role === 'admin') {
        // Admin sees all subjects for the section
        $query = "
            SELECT DISTINCT
                s.id           AS subject_id,
                s.subject_code,
                s.subject_name
            FROM instructor_section_tbl ist
            INNER JOIN subject_instructors_tbl si ON ist.instructor_id = si.instructor_id
            INNER JOIN subjects_tbl s ON si.subject_id = s.id
            WHERE ist.course = ? AND ist.section = ?
            ORDER BY s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("ss", $course, $section);

    } elseif ($facilitator_role === 'instructor') {
        // Instructor sees only their own subjects for the section
        $query = "
            SELECT DISTINCT
                s.id           AS subject_id,
                s.subject_code,
                s.subject_name
            FROM instructor_section_tbl ist
            INNER JOIN subject_instructors_tbl si
                ON ist.instructor_id = si.instructor_id
                AND si.instructor_id = ?
            INNER JOIN subjects_tbl s ON si.subject_id = s.id
            WHERE ist.course = ? AND ist.section = ? AND ist.instructor_id = ?
            ORDER BY s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("issi", $facilitator_id, $course, $section, $facilitator_id);

    } else {
        echo json_encode(['success' => false, 'message' => 'Invalid facilitator role']);
        exit;
    }

    $stmt->execute();
    $result = $stmt->get_result();

    $subjects = [];
    while ($row = $result->fetch_assoc()) {
        $subjects[] = [
            'subject_id'   => $row['subject_id'],
            'subject_code' => $row['subject_code'],
            'subject_name' => $row['subject_name'],
        ];
    }
    $stmt->close();

    if (empty($subjects)) {
        echo json_encode(['success' => false, 'message' => 'No subjects found for this section']);
    } else {
        echo json_encode(['success' => true, 'subjects' => $subjects]);
    }

} catch (Exception $e) {
    error_log("Get Subjects Error: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}

$conn->close();