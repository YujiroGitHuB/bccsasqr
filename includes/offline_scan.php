<?php
// ============================================================
//  Scans the app kept while it had no internet.
//
//  The app's scanner does not stop when the signal does: a scan it
//  cannot send is kept on the phone and sent later, in a batch, to
//  POST /api/v1/scanner/sync. Such a scan brings the one thing
//  scan_record() otherwise never takes from a caller — WHEN it
//  happened. The phone's clock is the only witness to that, so it is
//  taken, within limits, and the row says where it came from:
//
//    attendance_tbl.scanned_offline  1 for a row sent from the queue
//    attendance_tbl.synced_at        when the server received it;
//                                    `date` and time_in are the scan
//
//  The limits (offline_scan_time()):
//    · not in the future, beyond a few minutes of clock drift
//    · no older than OFFLINE_SCAN_MAX_DAYS calendar days — a class
//      scanned in a room with no signal on Friday still goes in when
//      the phone next opens the app on Monday
//
//  Everything else — whether the subject is theirs, enrolment, the
//  photo, duplicates — is scan_record()'s, run on the scan's own day.
// ============================================================

require_once __DIR__ . '/late.php';

/** How many calendar days back a kept scan may be dated. */
const OFFLINE_SCAN_MAX_DAYS = 3;

/** A phone's clock this far ahead of the server's is still believed. */
const OFFLINE_SCAN_SKEW_SECONDS = 600;

/**
 * Are both columns there? Adds them when they are not — the same
 * self-install as late_ready(), for the same reason: a deploy goes out
 * on push, and a migration is a separate manual step.
 * migrations/2026-09-30_add_offline_scans.sql has the same statements.
 *
 * False only when they are missing and cannot be added. A kept scan is
 * then still recorded, just without the mark — the attendance is what
 * the instructor is owed; the mark is for the admin.
 */
function offline_scan_ready(mysqli $conn): bool
{
    static $ready = null;
    if ($ready !== null) return $ready;

    // synced_at is added second, so its being there means both are.
    if (late_has_column($conn, 'attendance_tbl', 'synced_at')) return $ready = true;

    try {
        if (!late_has_column($conn, 'attendance_tbl', 'scanned_offline')) {
            $conn->query("
                ALTER TABLE attendance_tbl
                    ADD COLUMN scanned_offline TINYINT(1) NOT NULL DEFAULT 0
            ");
        }
        $conn->query("
            ALTER TABLE attendance_tbl
                ADD COLUMN synced_at DATETIME NULL DEFAULT NULL
        ");
    } catch (Throwable $e) {
        error_log('offline_scan_ready: ' . $e->getMessage());
    }

    return $ready = late_has_column($conn, 'attendance_tbl', 'synced_at');
}

/**
 * When a kept scan happened, from the app's `scanned_at`, in
 * Philippine time — or why it cannot be accepted.
 *
 * Only a full ISO 8601 instant with its offset is read
 * ("2026-09-30T00:25:54.120Z"). PHP's own parser would also take
 * "yesterday" or "+1 week", and a date is not something to let a
 * request phrase freely.
 *
 * @return array{at: ?DateTimeImmutable, code: ?string, error: ?string}
 */
function offline_scan_time(string $raw, DateTimeImmutable $now): array
{
    $raw = trim($raw);

    if (!preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/', $raw)) {
        return ['at' => null, 'code' => 'bad_time', 'error' => 'The time of this scan could not be read.'];
    }

    try {
        $at = (new DateTimeImmutable($raw))->setTimezone($now->getTimezone());
    } catch (Throwable $e) {
        return ['at' => null, 'code' => 'bad_time', 'error' => 'The time of this scan could not be read.'];
    }

    if ($at->getTimestamp() > $now->getTimestamp() + OFFLINE_SCAN_SKEW_SECONDS) {
        return ['at' => null, 'code' => 'bad_time', 'error' => "This scan is dated later than now. Check the phone's date and time."];
    }

    $oldest = $now->setTime(0, 0)->modify('-' . OFFLINE_SCAN_MAX_DAYS . ' days');
    if ($at < $oldest) {
        return ['at' => null, 'code' => 'too_old', 'error' => 'This scan is more than ' . OFFLINE_SCAN_MAX_DAYS . ' days old, so it can no longer be sent.'];
    }

    return ['at' => $at, 'code' => null, 'error' => null];
}
