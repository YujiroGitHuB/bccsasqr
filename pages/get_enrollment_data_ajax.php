<?php
// ============================================================
// SUBJECT ENROLLMENT — AJAX endpoint
//
// Why: student_subjects.php used to render every enrollment as an
// HTML table row and every student as a dropdown item. At 1,586
// enrollments that is 3.1 MB of markup, plus 1.2 MB for the student
// list — about 4.4 MB the browser had to download, parse and turn
// into ~19,000 DOM nodes before the first five rows could appear,
// and DataTables then re-indexed all of it.
//
// The same data as JSON is roughly 250 KB and 130 KB. DataTables
// builds the DOM for the current page only, and the student list is
// built for whatever the search actually matches.
//
// The same treatment students.php already had — see
// pages/get_students_ajax.php, which this follows.
//
// Two datasets, one file: both need the identical permission guard
// and the identical section scoping, and splitting them into two
// endpoints would mean maintaining that twice.
//
//   ?dataset=enrollments   (default) — rows for the table
//   ?dataset=students                — the student picker
//
// Deliberately NO cache: an assignment or removal has to show up
// on the next draw.
// ============================================================

ob_start();

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/enrollment_scope.php";

ob_clean();
header('Content-Type: application/json');

// The same guards as student_subjects.php, in the same order: a
// signed-in user, one of the two roles that page allows, and the
// permission itself.
if (empty($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized', 'data' => []]);
    exit;
}

$user_role = $_SESSION['role'] ?? 'instructor';
$user_id   = (int) ($_SESSION['user_id'] ?? 0);

if (!in_array($user_role, ['admin', 'instructor'], true)) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized', 'data' => []]);
    exit;
}

requirePermissionJson('enrollment.manage');

$sections = enrollment_scope_sections($conn, $user_role, $user_id);
$dataset  = $_GET['dataset'] ?? 'enrollments';

if ($dataset === 'students') {

    // The picker. Only the five fields the dropdown actually reads —
    // it used to carry seven data- attributes per student, three of
    // which repeated what the other four already said.
    $where  = enrollment_scope_where($conn, $user_role, $sections, 'course', 'section');
    $result = $conn->query("
        SELECT student_no, fullname, course, section
        FROM students_tbl
        WHERE $where
        ORDER BY course, section, fullname
    ");

    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'student_no' => $row['student_no'],
            'fullname'   => $row['fullname'],
            'course'     => $row['course'],
            'section'    => $row['section'],
        ];
    }

    echo json_encode(['success' => true, 'data' => $rows]);
    exit;
}

// The table. `ss.section` is the section recorded ON THE ENROLLMENT,
// which is not always the student's current one — a student can be
// promoted after being enrolled — so the scope is checked against
// the student's course and the enrollment's section, exactly as the
// page did before.
$where  = enrollment_scope_where($conn, $user_role, $sections, 'st.course', 'ss.section');
$result = $conn->query("
    SELECT ss.id, ss.student_no, st.fullname, st.course, ss.section,
           ss.subject_code, sub.subject_name
    FROM student_subjects_tbl ss
    INNER JOIN students_tbl  st  ON st.student_no    = ss.student_no
    INNER JOIN subjects_tbl  sub ON sub.subject_code = ss.subject_code
    WHERE $where
    ORDER BY st.course, ss.section, st.fullname
");

$rows = [];
while ($row = $result->fetch_assoc()) {
    $rows[] = [
        'id'           => (int) $row['id'],
        'student_no'   => $row['student_no'],
        'fullname'     => $row['fullname'],
        'course'       => $row['course'],
        'section'      => $row['section'],
        // Sent joined as well: it is what the column sorts and
        // searches on, and building it in JavaScript for every row on
        // every draw is work the database already did.
        'full_section' => $row['course'] . '-' . $row['section'],
        'subject_code' => $row['subject_code'],
        'subject_name' => $row['subject_name'],
    ];
}

echo json_encode(['success' => true, 'data' => $rows]);
