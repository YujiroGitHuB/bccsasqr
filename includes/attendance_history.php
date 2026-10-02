<?php
// ============================================================
// A student's attendance history — the Attendance Tracker's rules.
//
// Read by the web tracker (Tracker/crud/att_display.php) and by the
// app (api/v1/handlers/tracker.php), so a student who checks both
// sees the same count, the same subjects and the same late marks.
// The same arrangement as includes/scan_attendance.php for the two
// scanners.
//
// Since 2026-10-02 it counts absences too. The records alone cannot:
// they hold the days a student WAS marked present, never the days
// their class met. includes/absences.php answers that for the
// instructor's report — a class met on a day anyone in its section
// was marked present in the subject — and the same rule is used here,
// per enrolled subject, so a student sees the number their instructor
// sees.
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
 *   subjects      subject => [count, instructor, records, enrolled,
 *                 section, classes, absences, absent_dates], in name
 *                 order — enrolled subjects never attended included,
 *                 with no records
 *   total         how many times the student was marked present
 *   last_attended the newest date across all subjects, as a
 *                 timestamp, or null
 *   classes       class days so far across the enrolled subjects, or
 *                 null when absences cannot be counted
 *   absences      class days missed across them, or null
 *
 * Throws on a database failure; the caller decides what the student
 * is told. Absences are the exception: when they cannot be counted,
 * the tracker still answers with the days present, as it always has.
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
            $subjects[$subject] = attendance_subject_group($record['instructor'] ?? 'N/A');
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

    [$subjects, $classes, $absences] = attendance_count_absences($conn, $student, $subjects);

    return [
        'student'       => $student,
        'records'       => $records,
        'subjects'      => $subjects,
        'total'         => count($records),
        'last_attended' => $latest,
        'classes'       => $classes,
        'absences'      => $absences,
    ];
}

/**
 * One subject's entry, before anything is in it. The absence fields
 * stay empty for a subject the student is not enrolled in — a past
 * one, or one from before enrollments were kept: there is no class to
 * count its days by.
 */
function attendance_subject_group(string $instructor): array
{
    return [
        'count'        => 0,
        'instructor'   => $instructor,
        'records'      => [],
        'enrolled'     => false,
        'section'      => null,
        'classes'      => null,
        'absences'     => null,
        'absent_dates' => [],
    ];
}

/**
 * $subjects with every enrolled subject in it — the ones never
 * attended too, which the records alone would never list — and, for
 * each enrolled one:
 *
 *   classes       days its class met before today, plus every day the
 *                 student was marked present in it
 *   absences      days its class met before today without them
 *   absent_dates  those days, 'Y-m-d', newest first
 *
 * Today is left out until it is over: the class may still be lining
 * up at the scanner, and a student waiting their turn is not absent.
 * A scan today counts at once, as a class attended.
 *
 * Returns [subjects, classes, absences]. The two totals are null when
 * nothing can be counted — no enrollment on file, or the enrollment
 * tables cannot be read — and the subjects then come back as they
 * went in.
 */
function attendance_count_absences(mysqli $conn, array $student, array $subjects): array
{
    try {
        $enrolled = attendance_enrollments($conn, (string) $student['student_no']);
        if (!$enrolled) {
            return [$subjects, null, null];
        }
        $met   = attendance_class_days($conn, (string) $student['course'], $enrolled);
        $today = (string) $conn->query('SELECT CURDATE() AS d')->fetch_assoc()['d'];
    } catch (Throwable $e) {
        error_log('[attendance_history] absences not counted: ' . $e->getMessage());
        return [$subjects, null, null];
    }

    // The records' own subject names, by the key enrollments match on:
    // a live record is filed by its name, so that one is kept.
    $byKey = [];
    foreach (array_keys($subjects) as $name) {
        $byKey[attendance_subject_key((string) $name)] = $name;
    }

    $classesTotal  = 0;
    $absencesTotal = 0;

    foreach ($enrolled as $key => $class) {
        $days = $met[$key] ?? [];   // 'Y-m-d' => that day's instructor
        $name = $byKey[$key] ?? $class['subject'];

        if (!isset($subjects[$name])) {
            // Enrolled and never marked present — the subject the
            // student most needs to see. Its instructor is whoever
            // scanned the class last, if anyone has yet.
            ksort($days);
            $subjects[$name] = attendance_subject_group($days ? (string) end($days) : '');
        }

        $present = [];
        foreach ($subjects[$name]['records'] as $record) {
            $ts = strtotime((string) $record['date']);
            if ($ts) {
                $present[date('Y-m-d', $ts)] = true;
            }
        }

        $held   = $present;
        $missed = [];
        foreach (array_keys($days) as $day) {
            if ($day >= $today) {
                continue;
            }
            $held[$day] = true;
            if (!isset($present[$day])) {
                $missed[] = $day;
            }
        }
        rsort($missed);

        $subjects[$name]['enrolled']     = true;
        $subjects[$name]['section']      = $class['section'];
        $subjects[$name]['classes']      = count($held);
        $subjects[$name]['absences']     = count($missed);
        $subjects[$name]['absent_dates'] = $missed;

        $classesTotal  += count($held);
        $absencesTotal += count($missed);
    }

    // Name order, as the records came — the subjects added above would
    // otherwise trail at the end.
    uksort($subjects, fn($a, $b) => strcasecmp((string) $a, (string) $b));

    return [$subjects, $classesTotal, $absencesTotal];
}

/**
 * The subjects the student is enrolled in, keyed by
 * attendance_subject_key(): [subject name, bare section].
 *
 * student_subjects_tbl is what the scanner and the attendance links
 * check before they record anything, so every subject a student can be
 * marked present in is here. Its section is the class's, per subject —
 * for an irregular student, not the one on their record.
 */
function attendance_enrollments(mysqli $conn, string $student_no): array
{
    $stmt = $conn->prepare("
        SELECT sb.subject_name, ss.section
        FROM student_subjects_tbl ss
        INNER JOIN subjects_tbl sb ON sb.subject_code = ss.subject_code
        WHERE ss.student_no = ?
    ");
    $stmt->bind_param('s', $student_no);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $enrolled = [];
    foreach ($rows as $row) {
        $name = trim((string) $row['subject_name']);
        if ($name === '') {
            continue;
        }
        $enrolled[attendance_subject_key($name)] = [
            'subject' => $name,
            'section' => attendance_bare_section((string) $row['section']),
        ];
    }

    return $enrolled;
}

/**
 * The days each enrolled subject's class met, keyed like the
 * enrollments: [key => ['Y-m-d' => instructor]].
 *
 * includes/absences.php's rule: a class met on a day anyone in its
 * course and section was marked present in the subject. A record keeps
 * the enrollment's section (scan_attendance.php, link_checkin.php), so
 * this finds the student's real classmates, not their home section's.
 */
function attendance_class_days(mysqli $conn, string $course, array $enrolled): array
{
    $match  = [];
    $types  = 's';
    $params = [$course];
    foreach ($enrolled as $class) {
        $match[]  = '(subject = ? AND section = ?)';
        $types   .= 'ss';
        $params[] = $class['subject'];
        $params[] = $class['section'];
    }

    $stmt = $conn->prepare("
        SELECT subject, DATE(`date`) AS day, MAX(instructor) AS instructor
        FROM attendance_tbl
        WHERE course = ? AND (" . implode(' OR ', $match) . ")
        GROUP BY subject, DATE(`date`)
    ");
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $days = [];
    foreach ($rows as $row) {
        $days[attendance_subject_key((string) $row['subject'])][(string) $row['day']]
            = (string) ($row['instructor'] ?? '');
    }

    return $days;
}

/** How a subject is matched between enrollments and records: case and outer spaces aside. */
function attendance_subject_key(string $subject): string
{
    $subject = trim($subject);

    return function_exists('mb_strtolower') ? mb_strtolower($subject, 'UTF-8') : strtolower($subject);
}

/**
 * "BSIT-2A" → "2A", " 2a" → "2A" — link_bare_section()'s rule
 * (includes/link_checkin.php), the form a record keeps its section in.
 * Repeated rather than included: that file brings the whole check-in
 * with it.
 */
function attendance_bare_section(string $section): string
{
    $section = strtoupper(trim($section));

    return preg_match('/^[A-Z]+-(.+)$/', $section, $m) ? trim($m[1]) : $section;
}
