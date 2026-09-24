<?php
// ============================================================
// Late marking for attendance links.
//
// The instructor opens a link from 8:00 to 9:00 and says "on time
// until 8:15". Anyone who submits at 8:16 or later is still recorded
// — the link is open — but the row carries is_late = 1.
//
// Two columns:
//   attendance_links_tbl.late_after  the LAST on-time minute
//   attendance_tbl.is_late           stamped once, at submission
//
// ── Why late_after is a minute, not an instant ──────────────
// "On time until 8:15" means 8:15:40 is still on time: a student
// reads 8:15 on their phone and is right to think they made it. So a
// submission is late from late_after + 1 minute, and every value
// written here is truncated to :00 seconds.
//
// ── Why only today's value counts ───────────────────────────
// A link row is reused for the same class every meeting. A cutoff
// set on Monday and never cleared would, on Wednesday, mark the
// whole class late the moment the link opens. A late_after from any
// other day is treated as not set — everywhere, by the same SQL
// below, so the card, the student's page and the submission cannot
// disagree about it.
//
// ── Why the stamp is stored and not worked out later ────────
// The cutoff changes from meeting to meeting on one link row. By
// next week the row no longer knows what "late" meant today, so the
// answer has to be written down while it is still true.
// ============================================================

/**
 * SQL (for attendance_links_tbl) that is 1 when late_after is set
 * for today. Anything older is a cutoff from a previous meeting.
 */
const LATE_TODAY_SQL = "(late_after IS NOT NULL AND DATE(late_after) = CURDATE())";

/**
 * SQL that is 1 when a submission right now would be late.
 */
const LATE_NOW_SQL = "(late_after IS NOT NULL AND DATE(late_after) = CURDATE()
                       AND NOW() >= DATE_ADD(late_after, INTERVAL 1 MINUTE))";

/**
 * Are both columns there? Adds them when they are not.
 *
 * Deploys go out on push, and a migration is a separate manual step.
 * If the code arrived first and read a column that did not exist,
 * every student submission would fail until someone ran the SQL — so
 * the schema installs itself on first use, the same way
 * security_install() does. migrations/2026-09-24_add_late_marking.sql
 * carries the same statements for the record.
 *
 * Returns false only if the columns are missing and cannot be added
 * (no ALTER privilege). Every caller then behaves as if no cutoff is
 * set: nobody is marked late, and nothing breaks.
 */
function late_ready(mysqli $conn): bool
{
    static $ready = null;
    if ($ready !== null) return $ready;

    // One column checked on the common path, not two: late_install()
    // adds the link column first, so is_late existing means both do.
    if (late_has_column($conn, 'attendance_tbl', 'is_late')) return $ready = true;

    late_install($conn);
    return $ready = late_has_column($conn, 'attendance_tbl', 'is_late');
}

function late_has_column(mysqli $conn, string $table, string $column): bool
{
    try {
        // Both names are literals from this file, never user input.
        $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
        return $res && $res->num_rows > 0;
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * Each column checked on its own and added with a plain ADD COLUMN:
 * ADD COLUMN IF NOT EXISTS is MariaDB-only, and MySQL would reject
 * the whole statement.
 */
function late_install(mysqli $conn): void
{
    try {
        if (!late_has_column($conn, 'attendance_links_tbl', 'late_after')) {
            $conn->query("
                ALTER TABLE attendance_links_tbl
                    ADD COLUMN late_after DATETIME NULL DEFAULT NULL AFTER expires_at
            ");
        }
        if (!late_has_column($conn, 'attendance_tbl', 'is_late')) {
            $conn->query("
                ALTER TABLE attendance_tbl
                    ADD COLUMN is_late TINYINT(1) NOT NULL DEFAULT 0 AFTER time_in
            ");
        }
    } catch (Throwable $e) {
        error_log('late_install: ' . $e->getMessage());
    }
}

/**
 * The SET clause for late_after, from POST.
 *
 *   minutes=15   on time for the next 15 minutes
 *   at=08:15     from <input type="time">, today
 *   clear=1      no cutoff
 *
 * All arithmetic happens in SQL, on the database clock — the same
 * clock that checks the cutoff at submission (see includes/links.php
 * for why the two must never be mixed).
 *
 * A time that has already passed today is allowed, unlike an expiry:
 * setting "8:15" at 8:20 is a real thing to want, and it means
 * everyone who submits from now on is late. Submissions already
 * recorded are not re-marked.
 *
 * @return array{sql:?string,types:string,params:array,error:?string}
 */
function late_clause(array $in): array
{
    $none = ['sql' => null, 'types' => '', 'params' => [], 'error' => null];

    if (!empty($in['clear'])) {
        return ['sql' => 'late_after = NULL', 'types' => '', 'params' => [], 'error' => null];
    }

    if (isset($in['minutes'])) {
        $minutes = (int) $in['minutes'];

        // A grace period longer than a school day is not a grace period.
        if ($minutes < 1 || $minutes > 720) {
            return array_merge($none, ['error' => 'Grace period must be between 1 minute and 12 hours.']);
        }

        return [
            'sql'    => "late_after = DATE_FORMAT(DATE_ADD(NOW(), INTERVAL ? MINUTE), '%Y-%m-%d %H:%i:00')",
            'types'  => 'i',
            'params' => [$minutes],
            'error'  => null,
        ];
    }

    if (isset($in['at']) && trim($in['at']) !== '') {
        $raw = trim($in['at']);

        if (!preg_match('/^([01]\d|2[0-3]):([0-5]\d)$/', $raw)) {
            return array_merge($none, ['error' => 'Invalid time.']);
        }

        return [
            'sql'    => 'late_after = TIMESTAMP(CURDATE(), ?)',
            'types'  => 's',
            'params' => [$raw . ':00'],
            'error'  => null,
        ];
    }

    return $none;
}

/**
 * Columns to SELECT from attendance_links_tbl for a link's late state.
 * Paired with late_state_from_row().
 */
function late_state_columns(): string
{
    return "
        " . LATE_TODAY_SQL . "                                  AS late_on,
        TIMESTAMPDIFF(SECOND, NOW(), DATE_ADD(late_after, INTERVAL 1 MINUTE)) AS late_in,
        DATE_FORMAT(late_after, '%l:%i %p')                     AS late_label
    ";
}

/**
 * The late state the links page and the student's page need.
 *
 *   late_on     a cutoff is set for today
 *   late_in     seconds until submissions start counting as late
 *               (zero or less = already late)
 *   late_label  "8:15 AM" — the last on-time minute
 */
function late_state_from_row(?array $row): array
{
    $on = $row && (int) ($row['late_on'] ?? 0) === 1;

    return [
        'late_on'    => $on,
        'late_in'    => $on && $row['late_in'] !== null ? (int) $row['late_in'] : null,
        'late_label' => $on ? trim((string) $row['late_label']) : null,
    ];
}

// ─────────────────────────────────────────────────────────────
// The QR scanner's switch
//
// The scanner has no cutoff time. It has a switch: the instructor
// turns late marking on when the class has started, and every scan
// from then on is late until it is turned off. No time to set, no
// countdown to watch — the person holding the camera already knows
// when class began.
//
// Kept per (instructor, subject), because the scanner is not a link:
// it scans whoever walks up, from any section. The table reuses the
// late_after column — set to the moment it was switched on, NULL when
// off — and the same "only today counts" rule as above. So a switch
// left on at the end of Monday's class is off on Tuesday morning,
// without anyone remembering to turn it off.
//
// Separate from the link's cutoff on purpose: switching the scanner on
// says nothing about a link sent out for a make-up at 3 PM.
// ─────────────────────────────────────────────────────────────

/**
 * Is scan_late_tbl there (and is_late on attendance_tbl)? Creates the
 * table on first use, like late_install() adds the columns.
 */
function late_scan_ready(mysqli $conn): bool
{
    static $ready = null;
    if ($ready !== null) return $ready;

    if (!late_ready($conn)) return $ready = false;

    try {
        $conn->query("
            CREATE TABLE IF NOT EXISTS scan_late_tbl (
                instructor_id INT(11)     NOT NULL,
                subject_code  VARCHAR(50) NOT NULL,
                late_after    DATETIME    NULL DEFAULT NULL,
                updated_at    TIMESTAMP   NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                PRIMARY KEY (instructor_id, subject_code)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ");
        return $ready = true;
    } catch (Throwable $e) {
        error_log('late_scan_ready: ' . $e->getMessage());
        return $ready = false;
    }
}

/**
 * Is late marking on today, per subject, for one instructor?
 *
 * @return array<string, bool>  subject_code => on
 */
function late_scan_on(mysqli $conn, int $instructorId, array $codes): array
{
    $out = array_fill_keys($codes, false);
    if (empty($codes) || !late_scan_ready($conn)) return $out;

    $marks = implode(',', array_fill(0, count($codes), '?'));
    $stmt  = $conn->prepare("
        SELECT subject_code, " . LATE_TODAY_SQL . " AS is_on
        FROM scan_late_tbl
        WHERE instructor_id = ? AND subject_code IN ($marks)
    ");
    $stmt->bind_param('i' . str_repeat('s', count($codes)), $instructorId, ...$codes);
    $stmt->execute();

    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $out[$row['subject_code']] = (int) $row['is_on'] === 1;
    }
    $stmt->close();

    return $out;
}

/**
 * Is a scan right now late? True while the switch is on — decided on
 * the database's idea of "today", never the phone's.
 */
function late_scan_now(mysqli $conn, int $instructorId, string $subjectCode): bool
{
    return late_scan_on($conn, $instructorId, [$subjectCode])[$subjectCode] ?? false;
}

/**
 * Late state for a set of short codes, keyed by code. Every code is
 * present in the result; a code whose columns are missing reads as
 * "no cutoff".
 */
function late_states(mysqli $conn, array $codes): array
{
    $out = array_fill_keys($codes, late_state_from_row(null));
    if (empty($codes) || !late_ready($conn)) return $out;

    $marks = implode(',', array_fill(0, count($codes), '?'));
    $stmt  = $conn->prepare("
        SELECT short_code, " . late_state_columns() . "
        FROM attendance_links_tbl
        WHERE short_code IN ($marks)
    ");
    $stmt->bind_param(str_repeat('s', count($codes)), ...$codes);
    $stmt->execute();

    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $out[$row['short_code']] = late_state_from_row($row);
    }
    $stmt->close();

    return $out;
}
