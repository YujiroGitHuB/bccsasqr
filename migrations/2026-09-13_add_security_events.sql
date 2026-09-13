-- ============================================================
-- Security events: who tried something they should not have.
--
-- Failed and guessed sign-ins, forged face sign-ins, calls to
-- endpoints the caller has no permission for, tampered device
-- cookies, and requests carrying SQL / script / path injection
-- patterns. Written by includes/security_log.php, read by
-- pages/security_monitor.php.
--
-- OPTIONAL: includes/security_log.php creates this table by itself
-- the first time it has something to record (or when the Security
-- Monitor page is opened). Run this by hand only if the database
-- user is not allowed to CREATE TABLE. Keep it in step with
-- security_install() in that file.
--
-- Separate from attendance_audit_tbl: that table is about the
-- attendance link and is scoped per instructor. These rows carry
-- admin-level information (IP addresses, attempted emails) and are
-- not tied to a class.
--
-- VARCHAR, not TEXT, throughout — the database is 10 MB. Rows older
-- than 30 days are swept automatically, and a source repeating the
-- same event is capped at 20 rows per 10 minutes.
--
-- Safe to re-run.
--
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-13_add_security_events.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS security_events_tbl (
    id         INT(11)      NOT NULL AUTO_INCREMENT,
    created_at DATETIME     NOT NULL DEFAULT current_timestamp(),

    -- probe | brute_force | face_mismatch | access_denied | login_failed
    -- | login_disabled | cookie_forged | no_session | login_no_user
    event      VARCHAR(24)  NOT NULL,

    -- high | medium | low. Stored rather than derived so the page can
    -- filter on an index; the mapping lives in SECURITY_EVENTS.
    severity   VARCHAR(8)   NOT NULL,

    ip         VARCHAR(45)  DEFAULT NULL,
    -- users.id when signed in. No FOREIGN KEY: deleting an account
    -- must not delete the evidence of what it tried.
    user_id    INT(11)      DEFAULT NULL,
    -- What was aimed at: an email, a permission key, a pattern name.
    identifier VARCHAR(120) DEFAULT NULL,
    path       VARCHAR(160) DEFAULT NULL,
    detail     VARCHAR(255) DEFAULT NULL,
    user_agent VARCHAR(255) DEFAULT NULL,

    PRIMARY KEY (id),
    KEY idx_created  (created_at),
    -- The per-source cap and the brute-force count.
    KEY idx_ip_event (ip, event, created_at),
    KEY idx_severity (severity, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
