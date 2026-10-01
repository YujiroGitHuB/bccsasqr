<?php
// ============================================================
//  api/v1/handlers/live.php
//
//  The student's live feed, for the app:
//    POST /students/{no}/live — anything new on my record?
//
//  The app asks every few seconds while it is open, so a student
//  sees "Marked present" on the phone the moment the instructor's
//  scan lands — no pull to refresh. The whole history
//  (GET /students/{no}/attendance) is too heavy to ask for that
//  often, and its allowance is per IP: a class on the school Wi-Fi
//  is one address, and would use it up in a minute. This answers
//  with only what is new since the phone last looked, and counts
//  per student instead.
//
//  Counting per student needs proof, or the counter would let
//  anyone walk through the numbers unthrottled: the last name, as
//  My Profile and Check in take it. A wrong number and a wrong name
//  get the same message, so the feed says nothing about who exists.
//  A right pair learns no more than the public tracker already
//  shows for the number alone.
//
//  Records are never edited once written — the late mark is
//  stamped at the scan (includes/late.php) — only added or deleted.
//  So the newest id is a cursor for what was added, and the count
//  is enough for the phone to notice that one was deleted.
// ============================================================

require_once __DIR__ . '/../../../includes/late.php';
require_once __DIR__ . '/../../../includes/offline_scan.php';

/** The most records one answer carries; a phone far behind gets the newest. */
const LIVE_MAX_RECORDS = 25;

/**
 * POST /api/v1/students/{student_no}/live
 *
 * JSON: `last_name`, and `since` — the `cursor` of the previous
 * answer. Without `since` (the phone's first look) no records come
 * back, only where things stand: a phone set up today is not told
 * about every scan of the semester.
 */
function handle_student_live(mysqli $conn, string $raw_no): void
{
    $student_no = students_clean_no($raw_no);

    // Per student: a phone asks about four times a minute, a little
    // faster while its code is up for the scanner. Two phones of the
    // same student still fit.
    api_rate_limit('live|' . $student_no, 30, 60);

    // The tracker's lock (Tracker/view.php) closes the feed too, and
    // before the record is looked up, as the tracker does.
    if (gen_is_locked($conn)) {
        api_fail(503, 'tracker_locked', 'The attendance tracker is temporarily closed. Please try again later.');
    }

    $body = api_json_body();
    live_require_owner($conn, $student_no, $body['last_name'] ?? '');

    $since = live_cursor($body['since'] ?? null);

    $stmt = $conn->prepare("
        SELECT COUNT(*) AS n, COALESCE(MAX(id), 0) AS top
        FROM attendance_tbl
        WHERE student_no = ?
    ");
    $stmt->bind_param('s', $student_no);
    $stmt->execute();
    $stats = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $records = [];
    $more    = false;
    if ($since !== null) {
        // One past the limit, to know whether there were more.
        $rows = live_records_after($conn, $student_no, $since, LIVE_MAX_RECORDS + 1);
        $more = count($rows) > LIVE_MAX_RECORDS;
        foreach (array_slice($rows, 0, LIVE_MAX_RECORDS) as $row) {
            $records[] = live_record($row);
        }
    }

    api_ok([
        // The newest record's id: the `since` of the next look.
        'cursor'  => (int) $stats['top'],
        // Every record of the student's. Fewer than the phone
        // expects means one was deleted.
        'count'   => (int) $stats['n'],
        'records' => $records,
        'more'    => $more,
    ]);
}

/**
 * The student, but only for someone who knows the last name — My
 * Profile's check (photos_require_owner), on the feed's own counter:
 * the app asks often, and must not use up the student's photo
 * uploads or check-ins.
 */
function live_require_owner(mysqli $conn, string $student_no, $raw_last): array
{
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

/** `since` as a record id, or null for a first look. Anything else is a first look too. */
function live_cursor($raw): ?int
{
    if (is_int($raw)) {
        return max(0, $raw);
    }
    if (is_string($raw) && ctype_digit($raw)) {
        return (int) $raw;
    }

    return null;
}

/**
 * The student's records newer than $since, newest first.
 *
 * The late and offline columns install themselves on first use
 * elsewhere; until they have, every record reads on time and live.
 */
function live_records_after(mysqli $conn, string $student_no, int $since, int $limit): array
{
    $lateCol    = late_ready($conn) ? 'is_late' : '0 AS is_late';
    $offlineCol = offline_scan_ready($conn) ? 'scanned_offline' : '0 AS scanned_offline';

    $stmt = $conn->prepare("
        SELECT id, date, subject, instructor, time_in, $lateCol, $offlineCol
        FROM attendance_tbl
        WHERE student_no = ? AND id > ?
        ORDER BY id DESC
        LIMIT ?
    ");
    $stmt->bind_param('sii', $student_no, $since, $limit);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return $rows;
}

/** One row as the app reads it — the tracker's record, with its id. */
function live_record(array $row): array
{
    $ts = strtotime((string) $row['date']);

    return [
        'id'         => (int) $row['id'],
        // The tracker's fallback (includes/attendance_history.php), so
        // the phone files the record under the same subject.
        'subject'    => (string) ($row['subject'] ?? 'No Subject'),
        'instructor' => (string) ($row['instructor'] ?? ''),
        'date'       => $ts ? date('Y-m-d', $ts) : (string) $row['date'],
        'time_in'    => (string) $row['time_in'],
        'late'       => (int) $row['is_late'] === 1,
        // Kept on the instructor's phone with no signal and sent
        // later: the time is when it was scanned, not when it arrived.
        'offline'    => (int) $row['scanned_offline'] === 1,
    ];
}
