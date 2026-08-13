<?php
/**
 * API: Get Absences Data
 *
 * Students in a section at or above an absence threshold, counted by
 * SESSION (subject + date) rather than by date — see
 * includes/absences.php for why that distinction matters.
 *
 * POST: section, min_absences, subject (optional; '' = all subjects)
 */

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/absences.php";

// Feeds the absences modal on the attendance page, so it rides on the
// same permission as that page rather than a separate one.
requirePermissionJson('attendance.view');

header('Content-Type: application/json');

if (!isset($_SESSION['user_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$user_id = $_SESSION['user_id'];
$role    = $_SESSION['role'] ?? '';

$full_section = $_POST['section'] ?? '';
$min_absences = isset($_POST['min_absences']) ? (int) $_POST['min_absences'] : 3;
$subject      = trim($_POST['subject'] ?? '');

if (empty($full_section)) {
    echo json_encode(['success' => false, 'message' => 'Section is required']);
    exit;
}

// "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = trim($parts[0] ?? '');
$section = trim($parts[1] ?? $full_section);

if (!absence_can_access($conn, $role, $user_id, $course, $section)) {
    echo json_encode(['success' => false, 'message' => 'Access denied']);
    exit;
}

// Instructors only ever see their own subjects. An instructor asking
// for a specific subject that is not theirs is refused rather than
// silently widened.
$allowed = ($role === 'admin') ? [] : absence_instructor_subjects($conn, $user_id);

if ($subject !== '' && $role !== 'admin' && !in_array($subject, $allowed, true)) {
    echo json_encode(['success' => false, 'message' => 'That subject is not assigned to you.']);
    exit;
}

$report = absence_report($conn, $course, $section, [
    'allowed_subjects' => $allowed,
    'subject'          => $subject,
    'min_absences'     => $min_absences,
    'scope_required'   => $role !== 'admin',
]);

$students = [];
foreach ($report['students'] as $s) {
    $students[] = [
        'student_no'     => $s['student_no'],
        'name'           => $s['fullname'],
        'course'         => $s['course'],
        'attended'       => $s['attended'],
        'total_sessions' => $s['total_sessions'],
        'absences'       => $s['absences'],
        // Only the subjects this student actually missed — the modal
        // shows them under the name, and listing the clean ones there
        // would bury the point.
        'breakdown'      => array_values(array_filter(
            $s['breakdown'],
            fn($b) => $b['absences'] > 0
        )),
    ];
}

echo json_encode([
    'success'        => true,
    'students'       => $students,
    'total_sessions' => $report['total_sessions'],
    'subjects'       => $report['subjects'],
    'section_size'   => $report['section_size'],
    'section'        => $full_section,
    'subject'        => $subject,
    'min_absences'   => $min_absences,
]);
