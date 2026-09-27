<?php
// ============================================================
// A student's attendance history — the Attendance Tracker's rules.
//
// Read by the web tracker (Tracker/crud/att_display.php) and by the
// app (api/v1/handlers/tracker.php), so a student who checks both
// sees the same count, the same subjects and the same late marks.
// The same arrangement as includes/scan_attendance.php for the two
// scanners.
// ============================================================

require_once __DIR__ . '/late.php';

/**
 * Everything the tracker shows for one student number, or null when
 * no such student exists.
 *
 *   student       students_tbl row + photo_path (LEFT JOIN: the photo
 *                 is optional here; the tile falls back to initials)
 *   records       every attendance row, grouped order: subject, then
 *                 newest date first
 *   subjects      subject => [count, instructor, records]
 *   total         how many times the student was marked present
 *   last_attended the newest date across all subjects, as a
 *                 timestamp, or null
 *
 * Throws on a database failure; the caller decides what the student
 * is told.
 */
function attendance_history(mysqli $conn, string $student_no): ?array
{
    $find = $conn->prepare("
        SELECT s.student_no, s.fullname, s.course, s.section,
               p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
        LIMIT 1
    ");
    $find->bind_param('s', $student_no);
    $find->execute();
    $student = $find->get_result()->fetch_assoc();
    $find->close();

    if (!$student) {
        return null;
    }

    // A student looking up their own record should see a late mark
    // before the instructor mentions it, not after.
    $lateCol = late_ready($conn) ? 'is_late' : '0 AS is_late';
    $stmt = $conn->prepare("
        SELECT id, date, student_no, name, course, section,
               subject, instructor, time_in, $lateCol
        FROM attendance_tbl
        WHERE student_no = ?
        ORDER BY subject, date DESC
    ");
    $stmt->bind_param('s', $student_no);
    $stmt->execute();
    $records = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $subjects = [];
    $latest   = null;
    foreach ($records as $record) {
        $subject = $record['subject'] ?? 'No Subject';
        if (!isset($subjects[$subject])) {
            $subjects[$subject] = [
                'count'      => 0,
                'instructor' => $record['instructor'] ?? 'N/A',
                'records'    => [],
            ];
        }
        $subjects[$subject]['count']++;
        $subjects[$subject]['records'][] = $record;

        // The rows are sorted by subject before date, so the first one
        // is not the most recent overall — the maximum has to be found.
        $ts = strtotime((string) $record['date']);
        if ($ts && (!$latest || $ts > $latest)) {
            $latest = $ts;
        }
    }

    return [
        'student'       => $student,
        'records'       => $records,
        'subjects'      => $subjects,
        'total'         => count($records),
        'last_attended' => $latest,
    ];
}
