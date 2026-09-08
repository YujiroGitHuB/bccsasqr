<?php
/*
 * ============================================================
 * WHICH SECTIONS A USER MAY SEE ON THE ENROLLMENT PAGE
 *
 * An admin sees every section in the school. An instructor sees
 * only the ones assigned to them in instructor_section_tbl.
 *
 * That rule used to be written out twice inside
 * pages/student_subjects.php — once for the student list and once
 * for the enrollment table — and now the AJAX endpoint needs it a
 * third time. Three copies of a rule that decides WHOSE RECORDS
 * SOMEONE CAN SEE is one copy too many: change it in two places and
 * the third quietly starts handing an instructor another section's
 * students. It lives here instead.
 *
 * ── The empty case matters ──────────────────────────────────
 * An instructor with no sections assigned must see NOTHING. Built
 * naively, an empty list produces an empty WHERE clause, which
 * matches every row — the exact opposite. enrollment_scope_where()
 * returns '0' for that case, so the query comes back empty.
 * ============================================================
 */

/**
 * The sections this user may work with, as
 * [['course' => 'BSIT', 'section' => '1A', 'full_section' => 'BSIT-1A'], ...]
 *
 * For an admin these are read from the roster (every section that
 * has students in it); for an instructor, from their assignments.
 */
function enrollment_scope_sections(mysqli $conn, string $role, int $userId): array
{
    if ($role === 'admin') {
        $q = $conn->query("
            SELECT DISTINCT course, section,
                   CONCAT(course, '-', section) AS full_section
            FROM students_tbl
            ORDER BY course, section
        ");
        return $q ? $q->fetch_all(MYSQLI_ASSOC) : [];
    }

    $q = $conn->prepare("
        SELECT DISTINCT ist.course, ist.section,
               CONCAT(ist.course, '-', ist.section) AS full_section
        FROM instructor_section_tbl ist
        WHERE ist.instructor_id = ?
        ORDER BY ist.course, ist.section
    ");
    $q->bind_param("i", $userId);
    $q->execute();
    $rows = $q->get_result()->fetch_all(MYSQLI_ASSOC);
    $q->close();

    return $rows;
}

/**
 * A SQL condition limiting rows to those sections, ready to drop
 * into a WHERE. Always returns something safe to interpolate:
 *
 *   admin              → '1'   (no restriction)
 *   instructor         → '((course = ... AND section = ...) OR ...)'
 *   instructor, none   → '0'   (matches nothing — see the note above)
 *
 * $courseCol and $sectionCol are the qualified column names in the
 * calling query, because the course and the section do not always
 * come from the same table: an enrollment's section is the one
 * recorded on student_subjects_tbl, while the course belongs to the
 * student.
 *
 * The values are escaped here rather than bound: the number of
 * placeholders varies with how many sections a user has, and a
 * prepared statement cannot take a variable-length list. Nothing in
 * this string comes from a request — only from the two tables read
 * above.
 */
function enrollment_scope_where(
    mysqli $conn,
    string $role,
    array $sections,
    string $courseCol = 'course',
    string $sectionCol = 'section'
): string {
    if ($role === 'admin') {
        return '1';
    }

    if (empty($sections)) {
        return '0';
    }

    $parts = [];
    foreach ($sections as $s) {
        $parts[] = '(' . $courseCol . " = '" . $conn->real_escape_string($s['course']) . "'"
                 . ' AND ' . $sectionCol . " = '" . $conn->real_escape_string($s['section']) . "')";
    }

    return '(' . implode(' OR ', $parts) . ')';
}

// No closing PHP tag on purpose — see includes/systemConfig.php.
