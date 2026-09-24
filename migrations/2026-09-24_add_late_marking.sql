-- ============================================================
-- Late marking on attendance links.
--
-- The instructor sets "on time until 8:15" on a link. The link stays
-- open; a student who submits at 8:16 or later is still recorded,
-- with is_late = 1.
--
--   late_after  the LAST on-time minute. Submissions are late from
--               late_after + 1 minute. Only a value dated today
--               counts — the link row is reused every meeting, and a
--               cutoff left over from Monday must not mark Wednesday's
--               whole class late. NULL = no cutoff.
--
--   is_late     stamped once, at submission. Stored rather than
--               worked out later because the link's cutoff changes
--               every meeting, and next week it no longer knows what
--               "late" meant today.
--
-- includes/late.php adds both columns on first use if this has not
-- been run, so the order of deploy and migration does not matter.
-- This file is the record of it. Keep the two in step.
--
-- Safe to re-run: IF NOT EXISTS (MariaDB).
--
-- Run:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-24_add_late_marking.sql
-- ============================================================

ALTER TABLE attendance_links_tbl
    ADD COLUMN IF NOT EXISTS late_after DATETIME NULL DEFAULT NULL AFTER expires_at;

-- DEFAULT 0: every record that already exists was on time, because
-- there was no such thing as late when it was taken.
ALTER TABLE attendance_tbl
    ADD COLUMN IF NOT EXISTS is_late TINYINT(1) NOT NULL DEFAULT 0 AFTER time_in;

-- The QR scanner's late switch, per instructor and subject — the
-- scanner has no link row to hold one. late_after is the moment it was
-- switched on (NULL = off); like the link's, only a value dated today
-- counts, so a switch left on is off again the next day.
CREATE TABLE IF NOT EXISTS scan_late_tbl (
    instructor_id INT(11)     NOT NULL,
    subject_code  VARCHAR(50) NOT NULL,
    late_after    DATETIME    NULL DEFAULT NULL,
    updated_at    TIMESTAMP   NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    PRIMARY KEY (instructor_id, subject_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ── Check ───────────────────────────────────────────────────
SELECT short_code, expires_at, late_after
FROM attendance_links_tbl
ORDER BY id DESC
LIMIT 5;

SELECT COUNT(*) AS total, SUM(is_late) AS late
FROM attendance_tbl;
