<?php
// ============================================================
// One attendance-link check-in, for every door that takes one.
//
// The student's web form (crud/submit_attendance.php) and the app's
// Check in (POST /api/v1/checkin/{code}) both end here, so a rule
// added for one is a rule for both. The scanner and the link drifted
// apart once over the photo requirement, and the looser of the two
// was the one people used — that is the reason this file exists.
//
// It answers; it never echoes or exits. The caller turns the answer
// into its own response shape.
// ============================================================

require_once __DIR__ . '/photo_requirement.php';
require_once __DIR__ . '/attendance_integrity.php';
require_once __DIR__ . '/late.php';

/**
 * "BSIT-2A" → "2A", " 2a" → "2A": a section the way the enrollment
 * table keeps it, so a link's full section and an enrollment's bare one
 * can be compared. The course is a leading run of letters and a dash —
 * scan_clean_section()'s rule.
 */
function link_bare_section(string $section): string
{
    $section = strtoupper(trim($section));

    return preg_match('/^[A-Z]+-(.+)$/', $section, $m) ? trim($m[1]) : $section;
}

/**
 * Records attendance for $who['student_no'] through the link
 * $who['short_code'], after every check the web form has always made.
 *
 * $who: student_no, short_code, device_id (already verified by the
 * caller), fingerprint (browser-supplied, for the record only), ip.
 *
 * Returns:
 *   response  the web form's JSON, exactly as it has always been sent
 *   result    the audit outcome — 'ok', 'duplicate', 'link_expired', …
 *             (the vocabulary is in includes/attendance_integrity.php)
 *   subject   the subject's name, once the link has been read
 *   time_in   "08:04:12 AM" when recorded
 *   late      true when recorded after the link's cutoff
 */
function link_checkin(mysqli $conn, array $who): array
{
    date_default_timezone_set('Asia/Manila');

    $student_no  = (string) $who['student_no'];
    $short_code  = (string) $who['short_code'];
    $device_id   = (string) $who['device_id'];
    $fingerprint = (string) ($who['fingerprint'] ?? '');
    $client_ip   = (string) ($who['ip'] ?? '');
    $today       = date('Y-m-d');

    // The class this link is for. Unknown until its row is read, so the
    // rows logged before then carry NULL — correct: at those exits
    // there is no class to name yet.
    $subject_name  = null;
    $full_section  = null;
    $instructor_id = null;

    // Logged at every exit, refusals included. It used to sit after the
    // link checks, and six exits — bad link, dead link, closed link, no
    // such number, missing photo, failed INSERT — left no trace: each
    // was a person who tried, and the record said nothing happened.
    $audit = function (string $result) use (
        $conn, $student_no, $short_code, &$subject_name, &$full_section,
        &$instructor_id, $device_id, $fingerprint, $client_ip
    ) {
        // Two outcomes can be repeated by a script without end, since a
        // submission is not counted the way the lookup is. Capped, so
        // the log built to spot abuse cannot become the vehicle for it
        // on a ten-megabyte database: five rows per ten minutes per
        // device is enough to see something is happening.
        if (in_array($result, ['no_student', 'bad_link'], true)
            && !integrity_rate_ok($conn, 'lg:s:' . $result . ':' . $device_id, 5, 600)) {
            return;
        }

        integrity_log($conn, [
            'student_no'    => $student_no,
            'short_code'    => $short_code,
            'subject_name'  => $subject_name,
            'section'       => $full_section,
            'instructor_id' => $instructor_id,
            'device_id'     => $device_id,
            'fingerprint'   => $fingerprint,
            'ip'            => $client_ip,
            'result'        => $result,
        ]);
    };

    $answer = function (string $result, array $response, array $extra = []) use ($audit, &$subject_name) {
        $audit($result);
        return array_merge([
            'response' => $response,
            'result'   => $result,
            'subject'  => $subject_name,
            'time_in'  => null,
            'late'     => false,
        ], $extra);
    };

    // ── The whole form can be closed from Settings ──────────────────
    $locked = $conn->query("SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");
    if ($locked && $locked->num_rows > 0 && (int) $locked->fetch_assoc()['setting_value']) {
        return $answer('form_locked', ['success' => false, 'message' => 'Attendance form is currently locked. Please contact your instructor.']);
    }

    // ── 0. The link says which class this is ────────────────────────
    //
    // The short code is the only thing trusted: subject, section and
    // instructor are read from its row. When they came from the POST,
    // deactivating a link did nothing to a form already open, and
    // anyone who once saw the values could submit them forever.
    //
    // The time comparisons are in SQL: the database clock set
    // expires_at (crud/set_link_expiry.php), so the same clock decides
    // when it has passed. is_late is decided here too, on that clock —
    // see includes/late.php.
    $lateReady = late_ready($conn);
    $lateCols  = $lateReady
        ? LATE_NOW_SQL . " AS is_late, DATE_FORMAT(late_after, '%l:%i %p') AS late_label"
        : "0 AS is_late, NULL AS late_label";

    $linkStmt = $conn->prepare("
        SELECT subject_id, subject_code, subject_name, section, instructor_id, instructor_name,
               is_active,
               (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired,
               $lateCols
        FROM attendance_links_tbl
        WHERE short_code = ?
    ");
    $linkStmt->bind_param("s", $short_code);
    $linkStmt->execute();
    $linkResult = $linkStmt->get_result();

    if ($linkResult->num_rows === 0) {
        // The link is handed out as a QR, not typed, so a stream of
        // these is not a typo — someone is guessing.
        return $answer('bad_link', ['success' => false, 'message' => 'This attendance link is not valid.']);
    }

    $link = $linkResult->fetch_assoc();

    if ((int) $link['is_active'] !== 1) {
        return $answer('link_off', ['success' => false, 'message' => 'This attendance link has been deactivated by your instructor.']);
    }

    if ((int) $link['is_expired'] === 1) {
        // The question that could not be answered before: who arrived
        // after it closed.
        return $answer('link_expired', ['success' => false, 'message' => 'This attendance link has already closed. Please ask your instructor for a new one.']);
    }

    $subject_code    = trim($link['subject_code']);
    $subject_name    = trim($link['subject_name']);
    $full_section    = trim($link['section']);   // "BSIT-1A"
    $instructor_id   = (int) $link['instructor_id'];
    $instructor_name = trim($link['instructor_name']);
    $is_late         = (int) $link['is_late'] === 1 ? 1 : 0;
    $late_label      = trim((string) $link['late_label']);

    // ── 1. The student ───────────────────────────────────────────────
    $stmt = $conn->prepare("SELECT student_no, fullname, course, section FROM students_tbl WHERE student_no = ?");
    $stmt->bind_param("s", $student_no);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        // No such number in the whole school. One is a slipped digit;
        // thirty from one device in five minutes is not.
        return $answer('no_student', ['success' => false, 'message' => 'Student not found']);
    }
    $student = $result->fetch_assoc();

    // ── 1b. Photo requirement ────────────────────────────────────────
    // The scanner's rule (crud/save_attendance.php): the link is a door
    // into attendance too. This is the real check — the one in
    // crud/verify_student.php only tells the student early, and anyone
    // posting here directly skips it.
    if (photo_is_required($conn) && student_photo_missing($conn, $student_no)) {
        return $answer('photo_missing', [
            'success'    => false,
            'code'       => 'photo_required',
            'message'    => photo_required_message(),
            // Relative to pages/daily_attendance.php, the web form — as
            // crud/verify_student.php answers too.
            'upload_url' => '../student/StudentPhotoProfile.php',
        ]);
    }

    // ── 2. Enrolment ─────────────────────────────────────────────────
    $enroll = $conn->prepare("
        SELECT section
        FROM student_subjects_tbl
        WHERE student_no   = ?
          AND subject_code = ?
        LIMIT 1
    ");
    $enroll->bind_param("ss", $student_no, $subject_code);
    $enroll->execute();
    $enroll_result = $enroll->get_result();

    if ($enroll_result->num_rows === 0) {
        return $answer('not_enrolled', [
            'success' => false,
            'message' => 'You are not enrolled in ' . $subject_name . '. Please contact your instructor.',
        ]);
    }

    $enrolled_section_raw = trim($enroll_result->fetch_assoc()['section']); // "BSIT-1A" or "1A"

    // attendance_tbl keeps course and section in separate columns: the
    // course comes from students_tbl, and the section is saved bare —
    // "1A", not "BSIT-1A" — or no query that filters by it matches.
    $course = $student['course'];
    if (strpos($enrolled_section_raw, '-') !== false) {
        $section_to_save = trim(explode('-', $enrolled_section_raw, 2)[1]);
    } else {
        $section_to_save = $enrolled_section_raw;
    }

    // ── 2a. This section's class ─────────────────────────────────────
    //
    // Enrolled in the subject is not enough: one subject runs in many
    // sections, each with its own link. Checked only by subject, a
    // student holding another section's QR or code was recorded in that
    // class — through the app's Check in (found 2026-10-01), or by
    // anyone posting here directly. The web form's Verify step
    // (crud/verify_student.php) has always refused it, but Verify only
    // tells the student early; this is the check nobody skips.
    //
    // Against the ENROLLMENT section, not the student's home section:
    // the two differ on purpose — an irregular student attends another
    // section's class for one subject (see crud/promote_section.php) —
    // and the enrollment says which class that is. Bare sections are
    // compared, as Verify does: the enrollment does not keep the course.
    if ($full_section !== '' && link_bare_section($enrolled_section_raw) !== link_bare_section($full_section)) {
        return $answer('wrong_section', [
            'success' => false,
            'message' => 'This attendance link is for ' . $full_section . ', not your section. '
                       . 'You are enrolled in ' . $subject_name . ' under section ' . link_bare_section($enrolled_section_raw)
                       . ' — please use that class’s link.',
        ]);
    }

    // ── 2b. One device, one student ──────────────────────────────────
    //
    // The biggest hole is not technical: hold the link, type a
    // classmate's number, done — ten seconds each, and one phone could
    // submit the whole class before the first name is called. The
    // device id makes every classmate an extra step (clear the cookie,
    // reinstall the app), which breaks the routine. The determined few
    // are written to attendance_audit_tbl and shown on
    // pages/attendance_integrity.php.
    if (integrity_setting($conn, 'device_binding', '1') === '1') {
        $other = integrity_device_conflict($conn, $device_id, $short_code, $student_no);

        if ($other !== null) {
            return $answer('device_reuse', [
                'success' => false,
                'code'    => 'device_reuse',
                // Never says who used the phone first: whoever holds it
                // has no need to know. The audit trail has it, for the
                // instructor.
                'message' => 'This device has already recorded attendance for another student today. '
                           . 'Each student submits from their own phone — please ask your instructor to mark you manually.',
            ]);
        }
    }

    // ── 3. Already recorded today ────────────────────────────────────
    $dup = $conn->prepare("
        SELECT id FROM attendance_tbl
        WHERE student_no = ? AND date = ? AND subject = ?
        LIMIT 1
    ");
    $dup->bind_param("sss", $student_no, $today, $subject_name);
    $dup->execute();

    if ($dup->get_result()->num_rows > 0) {
        return $answer('duplicate', [
            'success' => false,
            'message' => 'You have already submitted your attendance for ' . $subject_name . ' today.',
        ]);
    }

    // ── 4. Record it ─────────────────────────────────────────────────
    $time_in = date('h:i:s A');

    // is_late only when the column exists: without it this INSERT would
    // fail for every student, cutoff or not.
    $lateInsCol = $lateReady ? ', is_late' : '';
    $lateInsVal = $lateReady ? ', ?' : '';

    $insert = $conn->prepare("
        INSERT INTO attendance_tbl
            (date, student_no, name, course, section, subject, instructor, time_in, user_id$lateInsCol)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?$lateInsVal)
    ");
    $insParams = [
        $today,
        $student_no,
        $student['fullname'],
        $course,
        $section_to_save,
        $subject_name,
        $instructor_name,
        $time_in,
        $instructor_id,
    ];
    if ($lateReady) $insParams[] = $is_late;

    $insert->bind_param("ssssssssi" . ($lateReady ? 'i' : ''), ...$insParams);
    $saved = $insert->execute();
    $insert->close();

    if (!$saved) {
        // Passed every check and still not recorded. Without this row a
        // student who says they submitted has no proof, and the record
        // looks as if they never tried.
        return $answer('save_failed', ['success' => false, 'message' => 'Failed to submit attendance. Please try again.']);
    }

    // Logged after the INSERT, never before: 'ok' means there really is
    // an attendance row, and integrity_device_conflict() counts these.
    // Logged first, a failed save would lock the device for someone who
    // was never recorded.
    //
    // Late is said in the same breath as "recorded": finding out from
    // the instructor a week later is the worse way to learn it.
    $response = $is_late
        ? [
            'success' => true,
            'late'    => true,
            'message' => 'Attendance submitted for ' . $subject_name . ' — marked LATE (on time was until ' . $late_label . ').',
        ]
        : ['success' => true, 'late' => false, 'message' => 'Attendance submitted successfully for ' . $subject_name . '!'];

    return $answer('ok', $response, ['time_in' => $time_in, 'late' => (bool) $is_late]);
}
