<?php
session_start();
header('Content-Type: application/json');
include __DIR__ . "/../includes/db_connect.php";
error_log("POST data: " . print_r($_POST, true));
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$full_section     = trim($_POST['section']          ?? '');
$facilitator_id   = intval($_POST['facilitator_id'] ?? 0); // cast to int agad
$facilitator_role = trim($_POST['facilitator_role'] ?? '');

if (empty($full_section)) {
    echo json_encode(['success' => false, 'message' => 'Section is required']);
    exit;
}

if (empty($facilitator_id) || empty($facilitator_role)) {
    echo json_encode(['success' => false, 'message' => 'Facilitator information is required']);
    exit;
}

$parts  = explode('-', $full_section, 2);
$course = $parts[0] ?? '';

try {
    if ($facilitator_role === 'admin') {
        $query = "
            SELECT DISTINCT
                s.id           AS subject_id,
                s.subject_code,
                s.subject_name
            FROM instructor_section_tbl ist
            INNER JOIN subject_instructors_tbl si ON ist.instructor_id = si.instructor_id
            INNER JOIN subjects_tbl s ON si.subject_id = s.id
            WHERE ist.course = ?
              AND ist.section = ?   -- full_section ang ilalagay dito
            ORDER BY s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("ss", $course, $full_section); // "BSIT", "BSIT-1A"

    } elseif ($facilitator_role === 'instructor') {
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
            WHERE ist.course = ?
              AND ist.section = ?   -- full_section ang ilalagay dito
            ORDER BY s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("iss", $facilitator_id, $course, $full_section); // fixed bind types
        //                  ^--- "i" for int, "ss" for two strings

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