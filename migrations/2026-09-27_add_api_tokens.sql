-- ============================================================
-- Sign-in tokens for the phone app's QR scanner.
--
-- The web scanner keeps an instructor signed in with a PHP session.
-- The app signs in once through POST /api/v1/auth/login and keeps the
-- token it gets back; every scanner request sends it.
--
--   token_hash    SHA-256 of the token. The token itself is never
--                 stored, so a copy of this table signs nobody in.
--   last_used_at  a token idle for 60 days stops working
--                 (API_TOKEN_IDLE_DAYS in includes/api_tokens.php).
--
-- Rows are deleted when the app signs out, when the account is
-- disabled, and when the password changes — so an instructor who
-- lost their phone can sign it out by changing their password.
--
-- includes/api_tokens.php creates this table on first use if this has
-- not been run, so the order of deploy and migration does not matter.
-- This file is the record of it. Keep the two in step.
--
-- Safe to re-run: IF NOT EXISTS.
--
-- Run:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-27_add_api_tokens.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS api_tokens_tbl (
    id           INT(11)      NOT NULL AUTO_INCREMENT,
    user_id      INT(11)      NOT NULL,
    token_hash   CHAR(64)     NOT NULL,
    device       VARCHAR(100) NULL DEFAULT NULL,
    created_at   DATETIME     NOT NULL DEFAULT current_timestamp(),
    last_used_at DATETIME     NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (id),
    UNIQUE KEY uq_token_hash (token_hash),
    KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
