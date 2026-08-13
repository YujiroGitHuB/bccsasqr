<?php
// ============================================================
// Promote a whole section to the next year level.
//
// Sections are stored as plain text on students_tbl ("2A"), so a
// promotion is just a rename of every matching row — there is no
// year_level column to increment. Doing it from the Edit modal
// meant ~130 individual saves per section, 13 sections a year.
//
// Two modes, both JSON:
//   mode=preview   — counts only, nothing is written. The modal
//                    calls this on every field change.
//   mode=promote   — performs the move inside a transaction.
//
// Deliberately NOT touched:
//   attendance_tbl  — it keeps its own copy of course/section per
//                     row. That copy is a snapshot of where the
//                     student was ON THAT DATE, so last year's
//                     records must keep saying "2A".
//   student_subjects_tbl — its `section` is the ENROLLMENT
//                     section, not the student's home section.
//                     crud/verify_student.php:72 relies on the two
//                     differing to support irregular students, so
//                     syncing it here would break them. New-year
//                     enrollments are made on pages/student_subjects.php.
// ============================================================

session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

// Same gate as pages/students.php — reshaping the master list is not
// something every instructor gets, but it can now be granted to one.
requirePermissionJson('students.promote');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method.']);
    exit;
}

$mode         = $_POST['mode'] ?? 'preview';
$course       = trim($_POST['course'] ?? '');
$from_section = trim($_POST['from_section'] ?? '');
$to_section   = trim($_POST['to_section'] ?? '');

if ($course === '' || $from_section === '' || $to_section === '') {
    echo json_encode(['success' => false, 'message' => 'Course, current section, and new section are all required.']);
    exit;
}

// students_tbl.section is varchar(10); anything longer is silently
// truncated by MySQL and the section quietly stops matching.
if (!preg_match('/^[A-Za-z0-9\-]{1,10}$/', $to_section)) {
    echo json_encode([
        'success' => false,
        'message' => 'The new section may only contain letters, numbers, and dashes (max 10 characters).'
    ]);
    exit;
}

// utf8mb4_general_ci makes the UPDATE case-insensitive, so "2a" and
// "2A" are the same target — catch that here rather than running a
// no-op that reports success.
if (strcasecmp($from_section, $to_section) === 0) {
    echo json_encode(['success' => false, 'message' => 'The new section is the same as the current one.']);
    exit;
}

// ─── Counts, shared by both modes ────────────────────────────────
// The confirm dialog shows these before anything is written, and
// the result dialog shows them again after.
function countRows(mysqli $conn, string $sql, string $course, string $section): int
{
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ss", $course, $section);
    $stmt->execute();
    $n = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
    $stmt->close();
    return $n;
}

$SQL_STUDENTS    = "SELECT COUNT(*) AS n FROM students_tbl WHERE course = ? AND section = ?";
$SQL_INSTRUCTORS = "SELECT COUNT(*) AS n FROM instructor_section_tbl WHERE course = ? AND section = ?";

$moving      = countRows($conn, $SQL_STUDENTS, $course, $from_section);
$destination = countRows($conn, $SQL_STUDENTS, $course, $to_section);
$instructors = countRows($conn, $SQL_INSTRUCTORS, $course, $from_section);

if ($mode === 'preview') {
    echo json_encode([
        'success'     => true,
        'moving'      => $moving,
        'destination' => $destination,   // > 0 means this is a merge, not a move
        'instructors' => $instructors
    ]);
    exit;
}

if ($moving === 0) {
    echo json_encode([
        'success' => false,
        'message' => "No students found in $course-$from_section."
    ]);
    exit;
}

// ─── The move ────────────────────────────────────────────────────
$move_instructors = !empty($_POST['move_instructors']);

$conn->begin_transaction();

try {
    $stmt = $conn->prepare("UPDATE students_tbl SET section = ? WHERE course = ? AND section = ?");
    $stmt->bind_param("sss", $to_section, $course, $from_section);
    if (!$stmt->execute()) {
        throw new Exception($stmt->error);
    }
    $students_moved = $stmt->affected_rows;
    $stmt->close();

    $instructors_moved   = 0;
    $instructors_skipped = 0;

    if ($move_instructors && $instructors > 0) {
        // instructor_section_tbl has a UNIQUE (instructor_id, section),
        // so an instructor already assigned to the destination would
        // abort the whole UPDATE. IGNORE skips just those rows...
        $stmt = $conn->prepare("UPDATE IGNORE instructor_section_tbl SET section = ? WHERE course = ? AND section = ?");
        $stmt->bind_param("sss", $to_section, $course, $from_section);
        if (!$stmt->execute()) {
            throw new Exception($stmt->error);
        }
        $instructors_moved = $stmt->affected_rows;
        $stmt->close();

        // ...and this clears what IGNORE left behind. Those rows point
        // at a section that no longer has students, and the instructor
        // already holds the destination — that is why they were
        // skipped.
        $stmt = $conn->prepare("DELETE FROM instructor_section_tbl WHERE course = ? AND section = ?");
        $stmt->bind_param("ss", $course, $from_section);
        if (!$stmt->execute()) {
            throw new Exception($stmt->error);
        }
        $instructors_skipped = $stmt->affected_rows;
        $stmt->close();
    }

    $conn->commit();

    echo json_encode([
        'success'             => true,
        'students_moved'      => $students_moved,
        'instructors_moved'   => $instructors_moved,
        'instructors_skipped' => $instructors_skipped,
        'merged_into'         => $destination,
        'message'             => "$students_moved student(s) moved from $course-$from_section to $course-$to_section."
    ]);

} catch (Exception $e) {
    $conn->rollback();
    echo json_encode([
        'success' => false,
        'message' => 'Promotion failed, nothing was changed: ' . $e->getMessage()
    ]);
}
