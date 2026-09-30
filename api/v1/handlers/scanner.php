<?php
// ============================================================
//  The QR scanner, for the phone app.
//
//    POST /auth/login           email + password → token
//    POST /auth/logout          forget this phone's token
//    GET  /auth/me              who the token belongs to
//    GET  /scanner/subjects     the subject picker, with late marking
//    POST /scanner/scan         record one scan
//    GET  /scanner/attendance   today's Attendance List
//    POST /scanner/late         switch late marking on or off
//    GET  /scanner/roster       one subject's class list, for offline
//    POST /scanner/sync         scans kept on the phone while offline
//
//  Every rule — who may scan which subject, duplicates, the photo
//  requirement, late marking — is in includes/scan_attendance.php,
//  shared with the web scanner. This file only signs the caller in and
//  translates the answers into the API's envelope.
// ============================================================

require_once __DIR__ . '/../lib/auth.php';
require_once __DIR__ . '/../../../includes/scan_attendance.php';

/**
 * POST /api/v1/auth/login
 *
 * The same checks as crud/login_process.php, in the same table, with
 * the same entries in the Security Monitor when they fail. One extra:
 * an account that cannot open the scanner is told so here, rather than
 * being handed a token for a screen that would refuse it.
 */
function handle_auth_login(mysqli $conn): void
{
    $body     = api_json_body();
    $email    = trim((string) ($body['email'] ?? ''));
    // Trimmed like the web form's password, so the same typing works in both.
    $password = trim((string) ($body['password'] ?? ''));
    $device   = (string) ($body['device'] ?? '');

    if ($email === '' || $password === '') {
        api_fail(400, 'missing_credentials', 'Enter your email and password.');
    }

    // Per email and IP: a teacher who mistypes twice never notices it; a
    // list of guesses against one account stops here.
    api_rate_limit('login:' . strtolower($email), 8, 300);

    $stmt = $conn->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // One answer for "no such email" and "wrong password": the app has
    // no reason to confirm which addresses have accounts.
    if (!$user) {
        security_failed_login('login_no_user', $email);
        api_fail(401, 'invalid_credentials', 'Incorrect email or password.');
    }

    if (!password_verify($password, (string) $user['password'])) {
        security_failed_login('login_failed', $email);
        api_fail(401, 'invalid_credentials', 'Incorrect email or password.');
    }

    // Checked after the password, so a disabled account is only
    // confirmed to someone who knows it.
    if (($user['status'] ?? 'active') === 'disabled') {
        security_failed_login('login_disabled', $email);
        api_fail(403, 'account_disabled', 'Your account has been disabled. Please contact the administrator.');
    }

    if (!api_user_can($user, 'qr.scanner')) {
        api_fail(403, 'no_scanner_access', 'Your account does not have access to the QR scanner. Please contact the administrator.');
    }

    $token = api_token_issue($conn, (int) $user['id'], $device);
    if ($token === null) {
        api_fail(503, 'service_unavailable', 'Sign-in is not available right now. Please try again.');
    }

    $userId = (int) $user['id'];
    $touch  = $conn->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
    $touch->bind_param("i", $userId);
    $touch->execute();
    $touch->close();

    api_ok([
        'token' => $token,
        'user'  => api_user_resource($user),
    ], 201);
}

/**
 * POST /api/v1/auth/logout
 *
 * Always succeeds: a token that is already gone is as signed out as
 * one removed just now, and the app clears its copy either way.
 */
function handle_auth_logout(mysqli $conn): void
{
    api_token_revoke($conn, api_auth_token());
    api_ok(['signed_out' => true]);
}

/** GET /api/v1/auth/me */
function handle_auth_me(mysqli $conn): void
{
    $user = api_require_user($conn);

    api_ok([
        'user'     => api_user_resource($user),
        'can_scan' => api_user_can($user, 'qr.scanner'),
    ]);
}

/**
 * What every scanner endpoint checks first: signed in, allowed to use
 * the scanner (the web page's own guard), and the QR pages not locked
 * in Settings — the lock that takes the web scanner offline takes the
 * app's offline too.
 */
function scanner_guard(mysqli $conn): array
{
    $user = api_require_user($conn);

    api_require_permission($user, 'qr.scanner', 'Your account does not have access to the QR scanner. Please contact the administrator.');

    if (gen_is_locked($conn)) {
        api_fail(503, 'scanner_locked', 'The QR scanner has been closed by the administrator. Please try again later.');
    }

    return $user;
}

/** GET /api/v1/scanner/subjects */
function handle_scanner_subjects(mysqli $conn): void
{
    $user   = scanner_guard($conn);
    $userId = (int) $user['id'];

    $subjects = scan_subjects($conn, $userId, scan_is_admin($conn, $userId));
    $late     = late_scan_on($conn, $userId, array_column($subjects, 'subject_code'));

    api_ok([
        'user'     => api_user_resource($user),
        'date'     => scan_now()->format('Y-m-d'),
        'subjects' => array_map(fn($s) => [
            'code' => (string) $s['subject_code'],
            'name' => (string) $s['subject_name'],
            'late' => $late[$s['subject_code']] ?? false,
        ], $subjects),
    ]);
}

/**
 * POST /api/v1/scanner/scan   { "student_no": "000-1023", "subject_code": "IT101" }
 *
 * The web scanner's crud/save_attendance.php, answer for answer. Each
 * refusal keeps the code the web page branches on (already_marked,
 * not_enrolled, …) so the app can say and show the same thing.
 */
function handle_scanner_scan(mysqli $conn): void
{
    $user = scanner_guard($conn);
    api_require_permission($user, 'attendance.record', 'Your account may not record attendance. Please contact the administrator.');

    $body = api_json_body();

    try {
        $result = scan_record(
            $conn,
            (int) $user['id'],
            (string) ($body['student_no']   ?? ''),
            (string) ($body['subject_code'] ?? '')
        );
    } catch (Throwable $e) {
        error_log('api scanner/scan: ' . $e->getMessage());
        api_fail(500, 'scan_failed', 'Could not save attendance. Please try again.');
    }

    if ($result['success']) {
        api_ok(['record' => scanner_record_resource((string) $body['student_no'], $result)], 201);
    }

    [$status, $message] = scanner_refusal($result);

    api_fail($status, $result['message'], $message, isset($result['name']) ? ['name' => $result['name']] : []);
}

/** A scan scan_record() stored, as the app reads it. */
function scanner_record_resource(string $studentNo, array $result): array
{
    return [
        'student_no'    => trim($studentNo),
        'name'          => (string) $result['name'],
        'course'        => (string) $result['course'],
        'section'       => (string) $result['section'],
        'subject'       => (string) $result['subject'],
        'date'          => $result['date'],
        'time_in'       => $result['time_in'],
        'late'          => $result['late'],
        'photo_url'     => api_asset_url($result['photo_path']),
        'photo_missing' => $result['photo_missing'],
    ];
}

/**
 * The HTTP status and message for a scan scan_record() refused; its
 * `message` is the code.
 *
 * @return array{0: int, 1: string}
 */
function scanner_refusal(array $result): array
{
    return match ($result['message']) {
        'already_marked'    => [409, 'Already marked today.'],
        'not_authorized'    => [403, $result['error']],
        'student_not_found' => [404, $result['error']],
        'photo_required'    => [422, $result['error']],
        'not_enrolled'      => [422, $result['error']],
        default             => [400, $result['error'] ?? 'Required fields are missing.'],
    };
}

/**
 * GET /api/v1/scanner/roster?subject=IT101
 *
 * The students enrolled in one of this account's subjects, so the app
 * can go on scanning that class with no internet — naming each student
 * and refusing the ones from another class, as it would online. See
 * scan_roster() for what is in it.
 */
function handle_scanner_roster(mysqli $conn): void
{
    $user   = scanner_guard($conn);
    $userId = (int) $user['id'];
    api_require_permission($user, 'attendance.record', 'Your account may not record attendance. Please contact the administrator.');

    $code = trim((string) ($_GET['subject'] ?? ''));
    if ($code === '') {
        api_fail(400, 'missing_data', 'Select a subject first.');
    }

    if (!scan_is_admin($conn, $userId) && !scan_owns_subject($conn, $userId, $code)) {
        api_fail(403, 'not_authorized', 'That subject is not assigned to you.');
    }

    api_ok([
        'date'           => scan_now()->format('Y-m-d'),
        'subject_code'   => $code,
        'photo_required' => photo_is_required($conn),
        'students'       => scan_roster($conn, $code),
    ]);
}

/** The most scans one POST /scanner/sync takes; the app sends in batches. */
const SCANNER_SYNC_MAX = 50;

/**
 * POST /api/v1/scanner/sync
 *
 *   { "scans": [ { "id": "k3f9…", "student_no": "000-1023",
 *                  "subject_code": "IT101",
 *                  "scanned_at": "2026-09-30T00:25:54.120Z",
 *                  "late": false }, … ] }
 *
 * Scans the app kept on the phone while it had no internet. Each one
 * goes through scan_record() on its own day and gets its own answer,
 * keyed by the id the app gave it:
 *
 *   saved           stored; `record` as /scanner/scan answers it
 *   already_marked  already in — sent before with the answer lost on
 *                   the way back, or scanned on the web meanwhile
 *   rejected        refused for good: `code` and `message`, the same
 *                   ones /scanner/scan gives, plus bad_time / too_old
 *   error           the database failed on this one; send it again
 *
 * Only what stops every scan fails the request as a whole: the
 * sign-in, the permission, the Settings lock. The app keeps the lot
 * and tries again later.
 */
function handle_scanner_sync(mysqli $conn): void
{
    $user   = scanner_guard($conn);
    $userId = (int) $user['id'];
    api_require_permission($user, 'attendance.record', 'Your account may not record attendance. Please contact the administrator.');

    $scans = api_json_body()['scans'] ?? null;
    if (!is_array($scans) || !array_is_list($scans)) {
        api_fail(400, 'invalid_body', 'Send the scans as a list under "scans".');
    }
    if (count($scans) > SCANNER_SYNC_MAX) {
        api_fail(400, 'too_many_scans', 'Send at most ' . SCANNER_SYNC_MAX . ' scans at a time.', ['max' => SCANNER_SYNC_MAX]);
    }

    $now     = scan_now();
    $results = [];

    foreach ($scans as $scan) {
        $id = is_array($scan) && is_scalar($scan['id'] ?? null) ? (string) $scan['id'] : '';
        // Nothing to key the answer by — the app has no way to match it.
        if ($id === '') continue;

        $time = offline_scan_time((string) ($scan['scanned_at'] ?? ''), $now);
        if ($time['at'] === null) {
            $results[] = ['id' => $id, 'status' => 'rejected', 'code' => $time['code'], 'message' => $time['error']];
            continue;
        }

        $studentNo = (string) ($scan['student_no'] ?? '');

        try {
            $result = scan_record(
                $conn,
                $userId,
                $studentNo,
                (string) ($scan['subject_code'] ?? ''),
                ['at' => $time['at'], 'late' => ($scan['late'] ?? false) === true]
            );
        } catch (Throwable $e) {
            error_log('api scanner/sync: ' . $e->getMessage());
            $results[] = ['id' => $id, 'status' => 'error', 'code' => 'scan_failed', 'message' => 'Could not save attendance. It will be sent again.'];
            continue;
        }

        if ($result['success']) {
            $results[] = ['id' => $id, 'status' => 'saved', 'record' => scanner_record_resource($studentNo, $result)];
        } elseif ($result['message'] === 'already_marked') {
            $results[] = ['id' => $id, 'status' => 'already_marked'];
        } else {
            [, $message] = scanner_refusal($result);
            $results[] = ['id' => $id, 'status' => 'rejected', 'code' => $result['message'], 'message' => $message];
        }
    }

    api_ok(['results' => $results]);
}

/** GET /api/v1/scanner/attendance — today's scans by this account. */
function handle_scanner_attendance(mysqli $conn): void
{
    $user = scanner_guard($conn);

    api_ok([
        'date'    => scan_now()->format('Y-m-d'),
        'records' => array_map(fn($r) => [
            'date'       => (string) $r['date'],
            'student_no' => (string) $r['student_no'],
            'name'       => (string) $r['name'],
            'course'     => (string) $r['course'],
            'section'    => (string) $r['section'],
            'subject'    => (string) ($r['subject'] ?? ''),
            'time_in'    => (string) $r['time_in'],
            'late'       => (int) $r['is_late'] === 1,
        ], scan_today($conn, (int) $user['id'])),
    ]);
}

/** POST /api/v1/scanner/late   { "subject_code": "IT101", "on": true } */
function handle_scanner_late(mysqli $conn): void
{
    $user = scanner_guard($conn);
    $body = api_json_body();

    $on = $body['on'] ?? false;
    $on = $on === true || $on === 1 || $on === '1' || $on === 'true';

    $result = scan_set_late($conn, (int) $user['id'], (string) ($body['subject_code'] ?? ''), $on);

    if (!$result['success']) {
        api_fail(422, 'late_not_changed', $result['message']);
    }

    api_ok([
        'subject_code' => $result['subject_code'],
        'on'           => $result['on'],
    ]);
}
