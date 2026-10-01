<?php
// ============================================================
//  api/v1/handlers/checkin.php
//
//  A student checking in through an instructor's attendance link,
//  from the app — the web form (pages/daily_attendance.php) without
//  the browser:
//    GET  /checkin/{code}  — which class is this, and is it open?
//    POST /checkin/{code}  — record me
//
//  No sign-in, as on the web. The app adds what the web form cannot
//  ask: the student's last name, the proof My Profile already took,
//  so a phone checks in only the student it was set up for. Every
//  other rule is includes/link_checkin.php, the web form's own.
// ============================================================

require_once __DIR__ . '/../../../includes/link_checkin.php';
require_once __DIR__ . '/../../../includes/links.php';

/**
 * The code as typed or read from the class QR. Six letters and digits
 * today (link_generate_code()); a little wider, so an older link still
 * answers instead of being called malformed.
 */
function checkin_clean_code(string $raw): string
{
    $code = preg_replace('/\s+/', '', trim($raw));

    if (!preg_match('/^[A-Za-z0-9]{4,16}$/', $code)) {
        api_fail(400, 'invalid_code', 'That is not a class code. It is six letters and numbers, like K7P2QX.');
    }

    return $code;
}

/** Settings → the attendance form's lock, which closes every link. */
function checkin_form_locked(mysqli $conn): bool
{
    $res = $conn->query("SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");

    return $res && $res->num_rows > 0 && (int) $res->fetch_assoc()['setting_value'] === 1;
}

/**
 * The student, but only for someone who knows the last name — My
 * Profile's check (photos_require_owner), on its own counter so a
 * class checking in cannot use up anyone's photo uploads.
 */
function checkin_require_owner(mysqli $conn, string $raw_no, $raw_last): array
{
    $student_no = students_clean_no($raw_no);
    api_rate_limit('checkin|' . $student_no, 10, 600);

    $last = photos_normalise_name(is_string($raw_last) ? $raw_last : '');
    if ($last === '') {
        api_fail(400, 'missing_last_name', 'Set up My Profile first: your student number and last name.');
    }

    $student = gen_find_student($conn, $student_no);

    if (!$student || !hash_equals(photos_last_name_of((string) $student['fullname']), $last)) {
        api_fail(403, 'identity_mismatch', 'This phone’s profile no longer matches the school record. Open My Profile and set it up again.');
    }

    return $student;
}

/**
 * GET /api/v1/checkin/{code}
 *
 * The class card the app shows before the student confirms: subject,
 * section, instructor, when the link closes and until when it counts
 * as on time. A closed or dead link answers with the web form's words.
 */
function handle_checkin_link(mysqli $conn, string $raw_code): void
{
    // Per IP, and loose: a whole class on the school Wi-Fi is one IP,
    // and they all open the same link in the same minute.
    api_rate_limit('checkin_link', 90, 60);

    $code = checkin_clean_code($raw_code);

    if (checkin_form_locked($conn)) {
        api_fail(503, 'form_locked', 'Attendance form is currently locked. Please contact your instructor.');
    }

    $stmt = $conn->prepare("
        SELECT short_code, subject_code, subject_name, section, instructor_name, is_active
        FROM attendance_links_tbl
        WHERE short_code = ?
    ");
    $stmt->bind_param('s', $code);
    $stmt->execute();
    $link = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$link) {
        api_fail(404, 'link_not_found', 'This attendance link is not valid.');
    }

    if ((int) $link['is_active'] !== 1) {
        api_fail(410, 'link_off', 'This attendance link has been deactivated by your instructor.');
    }

    // The code as the database keeps it: late_states() is keyed by it.
    $state = link_state($conn, (string) $link['short_code']);

    if ($state['is_expired']) {
        api_fail(410, 'link_expired', 'This attendance link has already closed. Please ask your instructor for a new one.');
    }

    api_ok([
        'short_code' => (string) $link['short_code'],
        'subject'    => [
            'code' => trim((string) $link['subject_code']),
            'name' => trim((string) $link['subject_name']),
        ],
        'section'    => trim((string) $link['section']),
        'instructor' => trim((string) $link['instructor_name']),
        // Labels from the database clock, as the web form shows them;
        // `in` is seconds from the server's now.
        'closes'     => [
            'label' => $state['expires_short'],
            'in'    => $state['expires_in'],
        ],
        'late'       => [
            'on'    => (bool) $state['late_on'],
            'label' => $state['late_label'],
            'in'    => $state['late_in'],
        ],
    ]);
}

/**
 * POST /api/v1/checkin/{code}
 *
 * JSON: `student_no`, `last_name`, and `device` — the token an earlier
 * answer handed this phone, or nothing the first time. Every answer,
 * refusals included, carries the token to keep (`device`), so the
 * phone stays one device for the one-device-one-student rule.
 */
function handle_checkin(mysqli $conn, string $raw_code): void
{
    api_rate_limit('checkin', 60, 60);

    $code    = checkin_clean_code($raw_code);
    $body    = api_json_body();
    $student = checkin_require_owner($conn, (string) ($body['student_no'] ?? ''), $body['last_name'] ?? '');

    $raw_device = is_string($body['device'] ?? null) ? $body['device'] : '';
    [$device_id, $token] = integrity_device_from_token($conn, $raw_device);

    $out = link_checkin($conn, [
        'student_no'  => (string) $student['student_no'],
        'short_code'  => $code,
        'device_id'   => $device_id,
        // The browser's fingerprint has no app counterpart worth
        // trusting; the device token stands in for both.
        'fingerprint' => '',
        'ip'          => integrity_client_ip(),
    ]);

    $response = $out['response'];

    if (!empty($response['success'])) {
        api_ok([
            'subject' => $out['subject'],
            'time_in' => $out['time_in'],
            'late'    => $out['late'],
            'message' => $response['message'],
            'device'  => $token,
        ]);
    }

    // The audit outcome, as the code the app switches on.
    $errors = [
        'form_locked'   => [503, 'form_locked'],
        'bad_link'      => [404, 'link_not_found'],
        'link_off'      => [410, 'link_off'],
        'link_expired'  => [410, 'link_expired'],
        'no_student'    => [404, 'student_not_found'],
        'photo_missing' => [403, 'photo_required'],
        'not_enrolled'  => [403, 'not_enrolled'],
        'device_reuse'  => [409, 'device_reuse'],
        'duplicate'     => [409, 'already_checked_in'],
    ];
    [$status, $error] = $errors[$out['result']] ?? [500, 'save_failed'];

    api_fail($status, $error, (string) $response['message'], ['device' => $token]);
}
