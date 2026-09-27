<?php
// ============================================================
//  api/v1/handlers/tracker.php
//
//  Ang Attendance Tracker (Tracker/view.php) para sa app:
//    GET /students/{no}/attendance — ilang beses na-present ang
//    estudyante, bawat subject, at kailan.
//
//  Walang login, gaya ng web: bukas ang tracker sa kahit sino na
//  may student number. Ang mga panuntunan ay nasa
//  includes/attendance_history.php, na binabasa rin ng web page.
// ============================================================

require_once __DIR__ . '/../../../includes/attendance_history.php';

/**
 * GET /api/v1/students/{student_no}/attendance
 *
 * The web tracker's result, as data: who the student is, the three
 * numbers at the top (times present, subjects, last attended), and
 * every subject with its dates, newest first.
 */
function handle_student_attendance(mysqli $conn, string $raw_no): void
{
    // The same allowance as the generator's lookup: plenty for a
    // student checking their own number, slow for a script walking
    // through everyone's.
    api_rate_limit('tracker', 20, 60);

    // The web tracker closes with the same Settings lock as the
    // generator and the scanner (Tracker/view.php). Checked before the
    // lookup, so a closed tracker does not confirm which numbers exist.
    if (gen_is_locked($conn)) {
        api_fail(503, 'tracker_locked', 'The attendance tracker is temporarily closed. Please try again later.');
    }

    $student_no = students_clean_no($raw_no);

    try {
        $history = attendance_history($conn, $student_no);
    } catch (Throwable $e) {
        error_log('[api/v1 tracker] ' . $e->getMessage());
        api_fail(500, 'tracker_failed', 'Could not load the attendance records. Please try again.');
    }

    if (!$history) {
        // The web tracker's wording.
        api_fail(404, 'student_not_found', 'Student not found. Please check your student number and try again.');
    }

    $student = $history['student'];

    $subjects = [];
    foreach ($history['subjects'] as $subject => $group) {
        $days = [];
        foreach ($group['records'] as $record) {
            $ts = strtotime((string) $record['date']);
            $days[] = [
                // The date alone: `date` is a DATETIME, and its time part
                // is the same instant as time_in, which is sent as the
                // scanner stored it.
                'date'    => $ts ? date('Y-m-d', $ts) : (string) $record['date'],
                'time_in' => (string) $record['time_in'],
                'late'    => (int) $record['is_late'] === 1,
            ];
        }

        $subjects[] = [
            // Cast: a subject named "101" arrives here as an int key.
            'subject'    => (string) $subject,
            'instructor' => (string) $group['instructor'],
            'count'      => (int) $group['count'],
            'records'    => $days,
        ];
    }

    api_ok([
        'student' => [
            'student_no' => $student['student_no'],
            'fullname'   => $student['fullname'],
            'course'     => $student['course'],
            'section'    => $student['section'],
            'photo_url'  => api_asset_url($student['photo_path'] ?? null),
        ],
        'summary' => [
            'total'         => (int) $history['total'],
            'subjects'      => count($subjects),
            'last_attended' => $history['last_attended'] ? date('Y-m-d', $history['last_attended']) : null,
        ],
        'subjects' => $subjects,
    ]);
}
