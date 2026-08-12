<?php
// ============================================================
// Absence counting, in one place.
//
// This used to be written out three times — api/get_absences_data.php,
// exports/export_absences_pdf.php and pages/dashboard.php — and all
// three counted the same wrong thing:
//
//     absences = COUNT(DISTINCT DATE(date)) for the section
//              - COUNT(DISTINCT DATE(date)) for the student
//
// A day is not a class. If 2A has CC221 and IT222 on the same Monday
// and a student attends CC221 but skips IT222, that student still has
// one distinct date and was counted PRESENT — the IT222 absence
// disappeared. The instructor subject filter did not help either: it
// narrowed WHICH rows were counted but still counted them by date, so
// an instructor teaching two subjects to one section lost the same
// way.
//
// A session here is a (subject, date) pair, which is what a class
// actually is. Everything below counts sessions, and the per-subject
// breakdown falls out of the same numbers, so the headline total and
// the breakdown can never disagree.
// ============================================================

/**
 * Subject names an instructor teaches. An empty array means "no
 * restriction" for admins; for an instructor with no subjects
 * assigned it means they legitimately see nothing.
 */
function absence_instructor_subjects(mysqli $conn, $user_id): array
{
    $stmt = $conn->prepare("
        SELECT s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        WHERE si.instructor_id = ?
    ");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $res = $stmt->get_result();

    $names = [];
    while ($row = $res->fetch_assoc()) {
        $names[] = $row['subject_name'];
    }
    $stmt->close();

    return $names;
}

/**
 * Builds the absence picture for one section.
 *
 * @param array $opts
 *   'allowed_subjects' => string[]  restrict to these (instructor scope); [] = no restriction
 *   'subject'          => string    report on this one subject only; '' = all
 *   'min_absences'     => int       students below this are dropped from 'students'
 *
 * @return array{
 *   total_sessions:int,
 *   subjects:array,          // [ ['subject'=>string,'sessions'=>int], ... ]
 *   section_size:int,
 *   students:array           // each with a per-subject 'breakdown'
 * }
 */
function absence_report(mysqli $conn, string $course, string $section, array $opts = []): array
{
    $allowed     = $opts['allowed_subjects'] ?? [];
    $subject     = trim($opts['subject'] ?? '');
    $minAbsences = (int) ($opts['min_absences'] ?? 0);

    // ── Scope shared by both attendance queries ──────────────────
    // Built with placeholders rather than escaped string interpolation,
    // which is what the three old copies did.
    $where  = "course = ? AND section = ?";
    $types  = "ss";
    $params = [$course, $section];

    if ($subject !== '') {
        $where   .= " AND subject = ?";
        $types   .= "s";
        $params[] = $subject;
    } elseif (!empty($allowed)) {
        $where   .= " AND subject IN (" . implode(',', array_fill(0, count($allowed), '?')) . ")";
        $types   .= str_repeat('s', count($allowed));
        $params   = array_merge($params, $allowed);
    }

    // An instructor with a scope but no subjects in it sees nothing —
    // not "everything", which is what an empty IN() list would have to
    // become to be valid SQL.
    $scopeIsEmpty = ($subject === '' && !empty($opts['scope_required']) && empty($allowed));

    // ── Sessions held, per subject ───────────────────────────────
    $subjects = [];
    $totalSessions = 0;

    if (!$scopeIsEmpty) {
        $sql = "SELECT COALESCE(subject,'') AS subject, COUNT(DISTINCT DATE(`date`)) AS sessions
                FROM attendance_tbl
                WHERE $where
                GROUP BY COALESCE(subject,'')
                ORDER BY subject ASC";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $res = $stmt->get_result();
        while ($row = $res->fetch_assoc()) {
            $subjects[] = ['subject' => $row['subject'], 'sessions' => (int) $row['sessions']];
            $totalSessions += (int) $row['sessions'];
        }
        $stmt->close();
    }

    // ── Sessions attended, per student per subject ───────────────
    $attended = [];   // [student_no][subject] => int
    if (!$scopeIsEmpty) {
        $sql = "SELECT student_no, COALESCE(subject,'') AS subject, COUNT(DISTINCT DATE(`date`)) AS attended
                FROM attendance_tbl
                WHERE $where
                GROUP BY student_no, COALESCE(subject,'')";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $res = $stmt->get_result();
        while ($row = $res->fetch_assoc()) {
            $attended[$row['student_no']][$row['subject']] = (int) $row['attended'];
        }
        $stmt->close();
    }

    // ── The roster ───────────────────────────────────────────────
    // From students_tbl, not from attendance_tbl: a student who has
    // never once been scanned still has to appear, and they are
    // exactly the ones worth catching.
    $stmt = $conn->prepare("
        SELECT student_no, fullname, course, section
        FROM students_tbl
        WHERE course = ? AND section = ?
        ORDER BY fullname ASC
    ");
    $stmt->bind_param("ss", $course, $section);
    $stmt->execute();
    $res = $stmt->get_result();

    $students     = [];
    $section_size = 0;

    while ($row = $res->fetch_assoc()) {
        $section_size++;

        $breakdown    = [];
        $attendedSum  = 0;

        foreach ($subjects as $s) {
            $got  = $attended[$row['student_no']][$s['subject']] ?? 0;
            $miss = max(0, $s['sessions'] - $got);
            $attendedSum += $got;

            $breakdown[] = [
                'subject'  => $s['subject'],
                'sessions' => $s['sessions'],
                'attended' => $got,
                'absences' => $miss,
            ];
        }

        $absences = max(0, $totalSessions - $attendedSum);

        if ($absences < $minAbsences) continue;

        $students[] = [
            'student_no'     => $row['student_no'],
            'fullname'       => $row['fullname'],
            'course'         => $row['course'],
            'section'        => $row['section'],
            'attended'       => $attendedSum,
            'total_sessions' => $totalSessions,
            'absences'       => $absences,
            'breakdown'      => $breakdown,
        ];
    }
    $stmt->close();

    // Worst first, then alphabetically — the order the old reports used.
    usort($students, function ($a, $b) {
        if ($a['absences'] !== $b['absences']) return $b['absences'] <=> $a['absences'];
        return strcmp($a['fullname'], $b['fullname']);
    });

    return [
        'total_sessions' => $totalSessions,
        'subjects'       => $subjects,
        'section_size'   => $section_size,
        'students'       => $students,
    ];
}

/**
 * Whether $user_id may look at $course-$section. Admins always may.
 */
function absence_can_access(mysqli $conn, $role, $user_id, string $course, string $section): bool
{
    if ($role === 'admin') return true;

    $stmt = $conn->prepare("
        SELECT COUNT(*) AS cnt FROM instructor_section_tbl
        WHERE instructor_id = ? AND course = ? AND section = ?
    ");
    $stmt->bind_param("iss", $user_id, $course, $section);
    $stmt->execute();
    $ok = ((int) $stmt->get_result()->fetch_assoc()['cnt']) > 0;
    $stmt->close();

    return $ok;
}
