<?php
// ============================================================
//  The QR scanner's rules, in one place.
//
//  Two scanners record attendance: the web page (Qrscanner/, through
//  crud/save_attendance.php) and the phone app (through
//  api/v1/scanner/*). Both call the functions below, so a rule changed
//  here — who may scan which subject, what counts as a duplicate, when
//  a scan is late — changes for both at once. Before the app existed
//  these rules lived inline in the crud/ files; a second copy for the
//  API would have drifted the first time either was fixed.
//
//  Every function takes the user id rather than reading the session:
//  the web passes $_SESSION['user_id'], the API passes the id behind
//  the app's sign-in token.
// ============================================================

require_once __DIR__ . '/photo_requirement.php';
require_once __DIR__ . '/late.php';

/**
 * "Today" and "now" for attendance — always Philippine time, whatever
 * the caller's default timezone happens to be. The web endpoint set
 * Asia/Manila itself; the API does not, and a UTC date would file an
 * early-morning scan under yesterday.
 */
function scan_now(): DateTimeImmutable
{
    return new DateTimeImmutable('now', new DateTimeZone('Asia/Manila'));
}

/**
 * Is this user an admin? Read from users, not from a session or a
 * token: a role changed by another admin counts from the next scan.
 */
function scan_is_admin(mysqli $conn, int $userId): bool
{
    $stmt = $conn->prepare("SELECT role FROM users WHERE id = ?");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $role = $stmt->get_result()->fetch_assoc()['role'] ?? null;
    $stmt->close();

    return $role === 'admin';
}

/** Is this subject assigned to this instructor? */
function scan_owns_subject(mysqli $conn, int $userId, string $subjectCode): bool
{
    $stmt = $conn->prepare("
        SELECT si.id
        FROM subject_instructors_tbl si
        INNER JOIN subjects_tbl s ON s.id = si.subject_id
        WHERE s.subject_code   = ?
          AND si.instructor_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("si", $subjectCode, $userId);
    $stmt->execute();
    $owns = $stmt->get_result()->num_rows > 0;
    $stmt->close();

    return $owns;
}

/**
 * The subjects this user may scan for, as [subject_code, subject_name]
 * rows sorted by name.
 *
 * An admin sees every subject that has an instructor; an instructor
 * sees only their own. The same list the scanner page's picker shows.
 */
function scan_subjects(mysqli $conn, int $userId, bool $isAdmin): array
{
    if ($isAdmin) {
        $res = $conn->query("
            SELECT DISTINCT s.subject_code, s.subject_name
            FROM subjects_tbl s
            INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
            ORDER BY s.subject_name
        ");
        return $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
    }

    $stmt = $conn->prepare("
        SELECT s.subject_code, s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        WHERE si.instructor_id = ?
        ORDER BY s.subject_name
    ");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $res  = $stmt->get_result();
    $rows = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
    $stmt->close();

    return $rows;
}

/**
 * Record one scan.
 *
 * Only WHICH student and WHICH subject come from the caller. Who is
 * scanning is $userId (the session or the token, never the request
 * body), when is the server's clock, and the subject's name comes from
 * subjects_tbl — each of those used to be taken from the request, and
 * each one was a way to file a record under someone else, on another
 * day, or against another class.
 *
 * Returns what crud/save_attendance.php has always answered, with one
 * difference: photo_path is the stored path, and each caller turns it
 * into a URL relative to itself.
 *
 *   success true   message 'saved', plus the stored record
 *   success false  message missing_data | not_authorized |
 *                  student_not_found | photo_required | not_enrolled |
 *                  already_marked
 *
 * Throws on a database failure; the caller decides what the scanner
 * is told.
 */
function scan_record(mysqli $conn, int $userId, string $studentNo, string $subjectCode): array
{
    $studentNo   = trim($studentNo);
    $subjectCode = trim($subjectCode);

    // One instant for all three, so the date, the time_in and the stored
    // datetime can never straddle a second — or midnight.
    $now      = scan_now();
    $date     = $now->format('Y-m-d');
    $time     = $now->format('h:i:s A');
    $datetime = $now->format('Y-m-d H:i:s');

    // ── 1. Validate required fields ───────────────────────────────────────────
    if ($studentNo === '' || $subjectCode === '' || $userId <= 0) {
        return [
            'success' => false,
            'message' => 'missing_data',
            'error'   => 'Required fields are missing',
        ];
    }

    $subj = $conn->prepare("SELECT subject_name FROM subjects_tbl WHERE subject_code = ? LIMIT 1");
    $subj->bind_param("s", $subjectCode);
    $subj->execute();
    $subject = $subj->get_result()->fetch_assoc()['subject_name'] ?? null;
    $subj->close();

    if ($subject === null) {
        return [
            'success' => false,
            'message' => 'missing_data',
            'error'   => 'That subject does not exist.',
        ];
    }

    // ── 2. Validate instructor is assigned to this subject ────────────────────
    if (!scan_is_admin($conn, $userId) && !scan_owns_subject($conn, $userId, $subjectCode)) {
        return [
            'success' => false,
            'message' => 'not_authorized',
            'error'   => "Subject '$subject' is not assigned to you. Please contact admin.",
        ];
    }

    // ── 3. Validate student exists & fetch details + photo ────────────────────
    $student_check = $conn->prepare("
        SELECT s.student_no, s.fullname, s.course, s.section, p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
    ");
    $student_check->bind_param("s", $studentNo);
    $student_check->execute();
    $student_data = $student_check->get_result()->fetch_assoc();
    $student_check->close();

    if (!$student_data) {
        return [
            'success' => false,
            'message' => 'student_not_found',
            'error'   => "Student $studentNo not found in database",
        ];
    }

    $name = $student_data['fullname'];

    // ── 3b. Photo requirement ─────────────────────────────────────────────────
    // The photo is the scanner's only visual proof of identity. With the
    // setting ON, a scan does not go through without one. With it OFF the
    // scan proceeds but a warning is sent to the scanner, so the
    // instructor knows they cannot confirm who is in front of them. The
    // default is OFF — see the migration for why. The photo_path is
    // already in hand from the query above, so only the setting is read
    // here; the scanner and the attendance link share that one answer.
    $photo_missing = empty($student_data['photo_path']);

    if (photo_is_required($conn) && $photo_missing) {
        return [
            'success' => false,
            'message' => 'photo_required',
            'name'    => $name,
            'error'   => "$name has no photo on file. Ask the admin to upload one before scanning.",
        ];
    }

    // ── 4. Check if student is enrolled in this subject ───────────────────────
    $enroll_check = $conn->prepare("
        SELECT section
        FROM student_subjects_tbl
        WHERE student_no   = ?
          AND subject_code = ?
        LIMIT 1
    ");
    $enroll_check->bind_param("ss", $studentNo, $subjectCode);
    $enroll_check->execute();
    $enroll_data = $enroll_check->get_result()->fetch_assoc();
    $enroll_check->close();

    if (!$enroll_data) {
        return [
            'success' => false,
            'message' => 'not_enrolled',
            'error'   => "$name is not enrolled in $subject",
        ];
    }

    // The section comes from the enrollment table — correct per subject.
    // A course prefix is stripped ("BSIT-2A" → "2A").
    $raw_section = $enroll_data['section'];
    $section     = preg_match('/^[A-Z]+-(.+)$/', $raw_section, $matches) ? $matches[1] : $raw_section;

    // ── 5. Check for duplicate entry (same subject + same date) ───────────────
    $dup_check = $conn->prepare("
        SELECT id
        FROM attendance_tbl
        WHERE student_no = ?
          AND subject    = ?
          AND DATE(date) = ?
        LIMIT 1
    ");
    $dup_check->bind_param("sss", $studentNo, $subject, $date);
    $dup_check->execute();
    $duplicate = $dup_check->get_result()->num_rows > 0;
    $dup_check->close();

    if ($duplicate) {
        return [
            'success' => false,
            'message' => 'already_marked',
        ];
    }

    // ── 6. Get instructor name ────────────────────────────────────────────────
    $inst = $conn->prepare("SELECT name FROM users WHERE id = ?");
    $inst->bind_param("i", $userId);
    $inst->execute();
    $instructor = $inst->get_result()->fetch_assoc()['name'] ?? '';
    $inst->close();

    // ── 6b. Late? ─────────────────────────────────────────────────────────────
    // Yes while this instructor has late marking switched on for this
    // subject today (includes/late.php).
    $is_late   = late_scan_now($conn, $userId, $subjectCode) ? 1 : 0;
    $lateReady = late_ready($conn);

    // ── 7. Insert attendance record ───────────────────────────────────────────
    // is_late only once the column exists — without it this INSERT
    // would fail for every scan.
    $lateInsCol = $lateReady ? ', is_late' : '';
    $lateInsVal = $lateReady ? ', ?' : '';

    $insert = $conn->prepare("
        INSERT INTO attendance_tbl
            (user_id, date, student_no, name, course, section, subject, instructor, time_in$lateInsCol)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?$lateInsVal)
    ");

    $insParams = [
        $userId,
        $datetime,
        $studentNo,
        $student_data['fullname'],
        $student_data['course'],
        $section,
        $subject,
        $instructor,
        $time,
    ];
    if ($lateReady) $insParams[] = $is_late;

    $insert->bind_param("issssssss" . ($lateReady ? 'i' : ''), ...$insParams);
    $insert->execute();
    $insert->close();

    return [
        'success'       => true,
        'message'       => 'saved',
        'late'          => (bool) $is_late,
        // What was stored, so the scanner shows the server's date and
        // time — not the phone's, which is never sent.
        'date'          => $date,
        'time_in'       => $time,
        'subject'       => $subject,
        'name'          => $student_data['fullname'],
        'course'        => $student_data['course'],
        'section'       => $section,
        'photo_path'    => $student_data['photo_path'] ?: null,
        // Attendance went in, but there is no face to show — the
        // scanner warns.
        'photo_missing' => $photo_missing,
    ];
}

/**
 * Today's scans by this user, newest first — the scanner's Attendance
 * List. is_late is 0 on servers where the column has not been added.
 */
function scan_today(mysqli $conn, int $userId): array
{
    $today   = scan_now()->format('Y-m-d');
    $lateCol = late_ready($conn) ? 'is_late' : '0 AS is_late';

    $stmt = $conn->prepare("
        SELECT date, student_no, name, course, section, subject, time_in, $lateCol
        FROM attendance_tbl
        WHERE user_id = ?
          AND DATE(date) = ?
        ORDER BY time_in DESC
    ");
    $stmt->bind_param("is", $userId, $today);
    $stmt->execute();
    $res  = $stmt->get_result();
    $rows = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
    $stmt->close();

    return $rows;
}

/**
 * Switch late marking on or off for one of this user's subjects.
 *
 * On: every scan from now on is saved as late. Off: on time. Keyed by
 * (user, subject); see includes/late.php.
 *
 * @return array{success:bool, message?:string, subject_code?:string, on?:bool}
 */
function scan_set_late(mysqli $conn, int $userId, string $subjectCode, bool $on): array
{
    $subjectCode = trim($subjectCode);

    if ($subjectCode === '') {
        return ['success' => false, 'message' => 'Select a subject first.'];
    }

    // The same check scan_record() makes before a scan: an admin can
    // scan any subject, an instructor only an assigned one.
    if (!scan_is_admin($conn, $userId) && !scan_owns_subject($conn, $userId, $subjectCode)) {
        return ['success' => false, 'message' => 'That subject is not assigned to you.'];
    }

    if (!late_scan_ready($conn)) {
        return ['success' => false, 'message' => 'Late marking is not available yet — the database could not be updated.'];
    }

    // On records the moment it was switched on — NOW(), on the database
    // clock that also decides what "today" is. Off is NULL.
    $stmt = $conn->prepare("
        INSERT INTO scan_late_tbl (instructor_id, subject_code, late_after)
        VALUES (?, ?, IF(?, NOW(), NULL))
        ON DUPLICATE KEY UPDATE late_after = VALUES(late_after)
    ");
    $onInt = $on ? 1 : 0;
    $stmt->bind_param('isi', $userId, $subjectCode, $onInt);
    $ok = $stmt->execute();
    $stmt->close();

    if (!$ok) {
        return ['success' => false, 'message' => 'Database error'];
    }

    return [
        'success'      => true,
        'subject_code' => $subjectCode,
        'on'           => late_scan_now($conn, $userId, $subjectCode),
    ];
}
