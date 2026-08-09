<?php
session_start();
include "../includes/db_connect.php";
include "../includes/auth.php";

header('Content-Type: application/json');

if (!in_array($_SESSION['role'] ?? '', ['admin', 'instructor'])) {
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$data   = json_decode(file_get_contents('php://input'), true);
$action = $data['action'] ?? '';

// ════════════════════════════════════════════════════════════
// ACTION: assign (individual)
// ════════════════════════════════════════════════════════════
if ($action === 'assign') {
    $student_no   = trim($data['student_no']   ?? '');
    $subject_code = trim($data['subject_code'] ?? '');
    $section      = trim($data['section']      ?? '');  // may dating "BSIT-1L" — i-strip ang prefix
    $course       = trim($data['course']       ?? '');  // "BSIT" — para sa strip lang, hindi isasave

    // Strip course prefix kung nakalagay — e.g. "BSIT-1L" → "1L"
    if (!empty($course) && str_starts_with($section, $course . '-')) {
        $section = substr($section, strlen($course) + 1);
    }
    // Fallback: kung may "-" pa rin, kuhanin lang yung huling part
    if (strpos($section, '-') !== false && preg_match('/^[A-Z]+-(.+)$/', $section, $m)) {
        $section = $m[1];
    }

    if (empty($student_no) || empty($subject_code) || empty($section)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields.']);
        exit;
    }

    $dup = $conn->prepare("SELECT id FROM student_subjects_tbl WHERE student_no = ? AND subject_code = ?");
    $dup->bind_param("ss", $student_no, $subject_code);
    $dup->execute();

    if ($dup->get_result()->num_rows > 0) {
        echo json_encode(['success' => false, 'error' => 'Student is already enrolled in this subject.']);
        exit;
    }

    // Insert raw section only — "1L" hindi "BSIT-1L"
    $insert = $conn->prepare("INSERT INTO student_subjects_tbl (student_no, subject_code, section) VALUES (?, ?, ?)");
    $insert->bind_param("sss", $student_no, $subject_code, $section);

    if ($insert->execute()) {
        echo json_encode(['success' => true, 'id' => $conn->insert_id, 'message' => 'Subject assigned successfully.']);
    } else {
        echo json_encode(['success' => false, 'error' => 'Insert failed: ' . $conn->error]);
    }
    exit;
}

// ════════════════════════════════════════════════════════════
// ACTION: bulk_assign (entire section)
// ════════════════════════════════════════════════════════════
if ($action === 'bulk_assign') {
    $raw_section  = trim($data['section']      ?? '');
    $course       = trim($data['course']       ?? '');
    $subject_code = trim($data['subject_code'] ?? '');

    // Strip course prefix just in case — "BSIT-1L" → "1L", "1L" → "1L"
    if (!empty($course) && str_starts_with($raw_section, $course . '-')) {
        $raw_section = substr($raw_section, strlen($course) + 1);
    } elseif (preg_match('/^[A-Z]+-(.+)$/', $raw_section, $m)) {
        $raw_section = $m[1];
    }

    if (empty($raw_section) || empty($subject_code)) {
        echo json_encode(['success' => false, 'error' => 'Missing required fields.']);
        exit;
    }

    // If course is provided, filter by course + section
    // If not, filter by section only (fallback)
    if (!empty($course)) {
        $students_q = $conn->prepare("SELECT student_no, fullname FROM students_tbl WHERE course = ? AND section = ?");
        $students_q->bind_param("ss", $course, $raw_section);
    } else {
        $students_q = $conn->prepare("SELECT student_no, fullname FROM students_tbl WHERE section = ?");
        $students_q->bind_param("s", $raw_section);
    }
    $students_q->execute();
    $students = $students_q->get_result()->fetch_all(MYSQLI_ASSOC);

    $section = $raw_section; // use stripped version

    if (empty($students)) {
        $label = !empty($course) ? "$course-$section" : $section;
        echo json_encode(['success' => false, 'error' => "No students found in section $label."]);
        exit;
    }

    $assigned  = 0;
    $skipped   = 0;
    $new_rows  = [];

    $dup_check = $conn->prepare("SELECT id FROM student_subjects_tbl WHERE student_no = ? AND subject_code = ?");
    // Insert raw section only — "1L" hindi "BSIT-1L"
    $insert    = $conn->prepare("INSERT INTO student_subjects_tbl (student_no, subject_code, section) VALUES (?, ?, ?)");

    foreach ($students as $student) {
        $sno = $student['student_no'];

        $dup_check->bind_param("ss", $sno, $subject_code);
        $dup_check->execute();

        if ($dup_check->get_result()->num_rows > 0) {
            $skipped++;
            continue;
        }

        $insert->bind_param("sss", $sno, $subject_code, $section);
        if ($insert->execute()) {
            $assigned++;
            $new_rows[] = ['id' => $conn->insert_id, 'student_no' => $sno, 'fullname' => $student['fullname']];
        }
    }

    echo json_encode(['success' => true, 'assigned' => $assigned, 'skipped' => $skipped, 'rows' => $new_rows]);
    exit;
}

// ════════════════════════════════════════════════════════════
// ACTION: remove (single)
// ════════════════════════════════════════════════════════════
if ($action === 'remove') {
    $id = intval($data['id'] ?? 0);

    if ($id <= 0) {
        echo json_encode(['success' => false, 'error' => 'Invalid ID.']);
        exit;
    }

    $delete = $conn->prepare("DELETE FROM student_subjects_tbl WHERE id = ?");
    $delete->bind_param("i", $id);

    if ($delete->execute()) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Delete failed: ' . $conn->error]);
    }
    exit;
}

// ════════════════════════════════════════════════════════════
// ACTION: bulk_remove (multiple selected rows)
// ════════════════════════════════════════════════════════════
if ($action === 'bulk_remove') {
    $ids = $data['ids'] ?? [];

    // Sanitize — integers only
    $ids = array_filter(array_map('intval', $ids), fn($id) => $id > 0);

    if (empty($ids)) {
        echo json_encode(['success' => false, 'error' => 'No valid IDs provided.']);
        exit;
    }

    // Build placeholders: ?,?,?
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $types        = str_repeat('i', count($ids));

    $delete = $conn->prepare("DELETE FROM student_subjects_tbl WHERE id IN ($placeholders)");
    $delete->bind_param($types, ...$ids);

    if ($delete->execute()) {
        echo json_encode(['success' => true, 'deleted' => $delete->affected_rows]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Bulk delete failed: ' . $conn->error]);
    }
    exit;
}

echo json_encode(['success' => false, 'error' => 'Unknown action.']);