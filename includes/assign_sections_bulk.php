<?php
session_start();
include "../includes/permissions.php";
include "../includes/db_connect.php";

header('Content-Type: application/json');

if (!isAdmin()) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$instructor_id = isset($_POST['instructor_id']) ? intval($_POST['instructor_id']) : 0;
$sections = isset($_POST['sections']) ? $_POST['sections'] : [];

if ($instructor_id <= 0) {
    echo json_encode(['success' => false, 'message' => 'Please select a valid instructor/admin']);
    exit;
}

if (empty($sections) || !is_array($sections)) {
    echo json_encode(['success' => false, 'message' => 'Please select at least one section']);
    exit;
}

// Verify instructor OR admin exists
$instructorCheck = mysqli_query($conn, "SELECT id, name, role FROM users WHERE id = $instructor_id AND role IN ('instructor', 'admin')");
if (mysqli_num_rows($instructorCheck) == 0) {
    echo json_encode(['success' => false, 'message' => 'Invalid instructor/admin selected']);
    exit;
}

$instructor = mysqli_fetch_assoc($instructorCheck);
$instructor_name = $instructor['name'];
$role_label = $instructor['role'] === 'admin' ? 'Admin' : 'Instructor';

// Track results
$assigned_count = 0;
$already_assigned = [];
$errors = [];

// Begin transaction
mysqli_begin_transaction($conn);

try {
    foreach ($sections as $section) {
    $section = mysqli_real_escape_string($conn, trim($section));
    
    // ✅ Split "BSIT-1A" → course = "BSIT", section = "1A"
    $parts   = explode('-', $section, 2);
    $course  = mysqli_real_escape_string($conn, $parts[0] ?? '');
    $section = mysqli_real_escape_string($conn, $parts[1] ?? $section);

    // Check combination ng course + section + instructor
    $checkQuery = mysqli_query($conn, "
        SELECT id FROM instructor_section_tbl
        WHERE course = '$course' AND section = '$section' AND instructor_id = $instructor_id
    ");

    if (mysqli_num_rows($checkQuery) > 0) {
        $already_assigned[] = "$course-$section";
        continue;
    }

    // INSERT na may course at section na separate
    $insertQuery = "INSERT INTO instructor_section_tbl (course, section, instructor_id) 
                    VALUES ('$course', '$section', $instructor_id)";

    if (mysqli_query($conn, $insertQuery)) {
        $assigned_count++;
    } else {
        $errors[] = "Failed to assign section: $course-$section";
    }
}

    if (!empty($errors)) {
        mysqli_rollback($conn);
        echo json_encode([
            'success' => false,
            'message' => 'Some assignments failed: ' . implode(', ', $errors)
        ]);
        exit;
    }

    mysqli_commit($conn);

    // Build success message
    $message = '';
    if ($assigned_count > 0) {
        $message = "Successfully assigned $assigned_count " . ($assigned_count == 1 ? 'section' : 'sections') . " to $role_label $instructor_name";
    }

    if (!empty($already_assigned)) {
        $skip_count = count($already_assigned);
        if ($message) $message .= ". ";
        $message .= "$skip_count " . ($skip_count == 1 ? 'section was' : 'sections were') . " already assigned to this instructor";
    }

    if ($assigned_count == 0 && !empty($already_assigned)) {
        $message = "All selected sections are already assigned to $role_label $instructor_name";
    }

    echo json_encode([
        'success' => true,
        'message' => $message,
        'assigned_count' => $assigned_count,
        'already_assigned_count' => count($already_assigned)
    ]);

} catch (Exception $e) {
    mysqli_rollback($conn);
    echo json_encode([
        'success' => false,
        'message' => 'An error occurred: ' . $e->getMessage()
    ]);
}

mysqli_close($conn);
?>