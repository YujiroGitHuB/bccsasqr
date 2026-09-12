<?php
// ============================================================
// The attendance summary — the rows behind the Summary tab of
// pages/attendance.php and behind exports/export_summary_pdf.php.
//
// Why it is here and not in either of them: the two used to hold
// the SAME query, copied, with a comment in the export saying so
// ("Deliberately the same two queries as pages/get_summary_ajax.php").
// That was survivable while the answer was one COUNT. It is not
// survivable now that a row carries an attended count AND the number
// of sessions it is out of: two copies of that arithmetic is two
// chances for the tab and the signed PDF exported from it to print
// different numbers for the same student.
//
// Same reasoning as includes/absences.php, and the same definition of
// a session: a (class, date) pair, never a bare date. If 2A has CC221
// and IT222 on one Monday, that Monday is two sessions.
//
// ── What "out of" counts ────────────────────────────────────
// Sessions held for that class FROM THE STUDENT'S FIRST SCAN in it,
// not from the first session of the class. A student transferred in
// at the fifth meeting is not carried four absences they could not
// have attended.
//
// The cost of that choice, which is worth knowing when reading the
// column: someone whose first scan is the last session reads 1/1.
// The date the count starts from rides along in `first_seen` so the
// screen can say where the denominator begins.
// ============================================================

/**
 * Every (student, subject) pair in scope, with what they attended and
 * what that is out of.
 *
 * Scoping is the same rule both callers already used: an admin sees
 * every student and every record; an instructor sees only their
 * assigned sections, counting only the attendance they themselves
 * recorded.
 *
 * @return array<int, array{
 *   student_no:string, fullname:string, course:string, section:string,
 *   subject:?string, attended:int, sessions_held:int, first_seen:?string
 * }>
 */
function attendance_summary_rows(mysqli $conn, bool $isAdmin, int $user_id): array
{
    // ── Scope ────────────────────────────────────────────────────
    // For an instructor this is built from instructor_section_tbl and
    // never from the request; each value is escaped all the same.
    $sectionWhere = '';
    $recordedBy   = '';

    if (!$isAdmin) {
        $secStmt = $conn->prepare("
            SELECT course, section
            FROM instructor_section_tbl
            WHERE instructor_id = ?
        ");
        $secStmt->bind_param("i", $user_id);
        $secStmt->execute();
        $secResult = $secStmt->get_result();

        $assigned = [];
        while ($row = $secResult->fetch_assoc()) {
            $assigned[] = $row;
        }
        $secStmt->close();

        // An instructor with no sections assigned sees nothing. Not
        // everything — which is what an empty condition would mean.
        if (empty($assigned)) return [];

        $sectionWhere = 'WHERE ' . implode(' OR ', array_map(
            fn($s) => "(s.course = '" . $conn->real_escape_string($s['course']) . "'"
                    . " AND s.section = '" . $conn->real_escape_string($s['section']) . "')",
            $assigned
        ));
        $recordedBy = " AND a.user_id = " . (int) $user_id;
    }

    // ── 1. What each student attended ────────────────────────────
    // COUNT(DISTINCT DATE(a.date)), not COUNT(a.id), which is what
    // both callers counted before. Two scans on one day are one
    // session attended; counting rows could print 7/6.
    //
    // MIN is where this student's own denominator starts.
    $rows = [];

    $sql = "
        SELECT s.student_no, s.fullname, s.course, s.section,
               a.subject,
               COUNT(DISTINCT DATE(a.`date`)) AS attended,
               MIN(DATE(a.`date`))            AS first_seen
        FROM students_tbl s
        LEFT JOIN attendance_tbl a
            ON s.student_no = a.student_no $recordedBy
        $sectionWhere
        GROUP BY s.student_no, s.fullname, s.course, s.section, a.subject
        ORDER BY s.fullname ASC, a.subject ASC
    ";
    $res = $conn->query($sql);
    if (!$res) return [];

    while ($row = $res->fetch_assoc()) {
        $rows[] = $row;
    }

    // ── 2. When each class actually met ──────────────────────────
    // A session is a date somebody was scanned for that class. The
    // same join and the same scope as the query above on purpose: if
    // the two drew from different populations, a student could attend
    // a session that the denominator does not know happened.
    //
    // One query, merged in PHP, rather than a correlated subquery per
    // row — this runs against a remote MySQL and the round trip is
    // the expensive part.
    $calendar = [];   // "course|section|subject" => [ 'YYYY-MM-DD', ... ]

    $calSql = "
        SELECT s.course, s.section, a.subject, DATE(a.`date`) AS d
        FROM students_tbl s
        INNER JOIN attendance_tbl a
            ON s.student_no = a.student_no $recordedBy
        $sectionWhere
        GROUP BY s.course, s.section, a.subject, DATE(a.`date`)
    ";
    $calRes = $conn->query($calSql);
    if ($calRes) {
        while ($c = $calRes->fetch_assoc()) {
            $calendar[$c['course'] . '|' . $c['section'] . '|' . (string) $c['subject']][] = $c['d'];
        }
    }

    // ── 3. Put the two together ──────────────────────────────────
    $out = [];

    foreach ($rows as $row) {
        $attended  = (int) $row['attended'];
        $firstSeen = $row['first_seen'];   // NULL = never scanned

        $held = 0;
        if ($firstSeen !== null) {
            $key   = $row['course'] . '|' . $row['section'] . '|' . (string) $row['subject'];
            $dates = $calendar[$key] ?? [];
            foreach ($dates as $d) {
                if ($d >= $firstSeen) $held++;
            }
        }

        // A student cannot have attended a session that was not held.
        // If that ever happens the data is wrong, and the honest thing
        // is to show it as complete rather than print 5/3.
        if ($held < $attended) $held = $attended;

        $out[] = [
            'student_no'    => $row['student_no'],
            'fullname'      => $row['fullname'],
            'course'        => $row['course'],
            'section'       => $row['section'],
            'subject'       => $row['subject'],
            'attended'      => $attended,
            'sessions_held' => $held,
            'first_seen'    => $firstSeen,
        ];
    }

    return $out;
}
