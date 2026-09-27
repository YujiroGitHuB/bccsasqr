<?php
// ============================================================
//  Sign-in tokens for the phone app.
//
//  The web keeps an instructor signed in with a PHP session cookie. The
//  app has no cookie jar worth trusting across restarts, so signing in
//  there hands back a random token instead, which the app keeps and
//  sends with every scanner request (api/v1/lib/auth.php).
//
//  Only a SHA-256 of the token is stored. A copy of this table — a
//  backup, a leaked dump — is then a list of hashes nobody can sign in
//  with, the same reason passwords are hashed.
//
//  A token lasts until the instructor signs out, or until it has sat
//  unused for API_TOKEN_IDLE_DAYS. Changing the password signs every
//  phone out (api_tokens_revoke_user() in crud/updateProfile.php and
//  crud/save_user.php): that is the one thing an instructor who lost
//  their phone will think to do.
//
//  The table installs itself on first use, like scan_late_tbl — deploys
//  go out on push and a migration is a separate manual step.
//  migrations/2026-09-27_add_api_tokens.sql carries the same statement
//  for the record.
// ============================================================

/** A phone not used for this long has to sign in again. */
const API_TOKEN_IDLE_DAYS = 60;

function api_tokens_ready(mysqli $conn): bool
{
    static $ready = null;
    if ($ready !== null) return $ready;

    try {
        $conn->query("
            CREATE TABLE IF NOT EXISTS api_tokens_tbl (
                id           INT(11)     NOT NULL AUTO_INCREMENT,
                user_id      INT(11)     NOT NULL,
                token_hash   CHAR(64)    NOT NULL,
                device       VARCHAR(100) NULL DEFAULT NULL,
                created_at   DATETIME    NOT NULL DEFAULT current_timestamp(),
                last_used_at DATETIME    NOT NULL DEFAULT current_timestamp(),
                PRIMARY KEY (id),
                UNIQUE KEY uq_token_hash (token_hash),
                KEY idx_user (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ");
        return $ready = true;
    } catch (Throwable $e) {
        error_log('api_tokens_ready: ' . $e->getMessage());
        return $ready = false;
    }
}

function api_token_hash(string $token): string
{
    return hash('sha256', $token);
}

/**
 * Creates a token for this user and returns it — the only time the
 * plain value exists on the server.
 */
function api_token_issue(mysqli $conn, int $userId, string $device = ''): ?string
{
    if (!api_tokens_ready($conn)) return null;

    $token  = bin2hex(random_bytes(32));
    $hash   = api_token_hash($token);
    $device = mb_substr(trim($device), 0, 100) ?: null;

    $stmt = $conn->prepare("INSERT INTO api_tokens_tbl (user_id, token_hash, device) VALUES (?, ?, ?)");
    $stmt->bind_param("iss", $userId, $hash, $device);
    $stmt->execute();
    $stmt->close();

    return $token;
}

/**
 * The account behind a token, or null when the token is unknown,
 * idle too long, or belongs to a disabled or deleted account.
 *
 * The account is read fresh on every call, so disabling an instructor
 * locks their phone out on its very next request.
 */
function api_token_user(mysqli $conn, string $token): ?array
{
    if ($token === '' || !api_tokens_ready($conn)) return null;

    $hash = api_token_hash($token);

    $stmt = $conn->prepare("
        SELECT t.id AS token_id,
               t.last_used_at < DATE_SUB(NOW(), INTERVAL " . API_TOKEN_IDLE_DAYS . " DAY) AS idle,
               t.last_used_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE) AS stale,
               u.*
        FROM api_tokens_tbl t
        INNER JOIN users u ON u.id = t.user_id
        WHERE t.token_hash = ?
        LIMIT 1
    ");
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) return null;

    $disabled = ($row['status'] ?? 'active') === 'disabled';

    if ((int) $row['idle'] === 1 || $disabled) {
        api_token_revoke($conn, $token);
        return null;
    }

    // At most one write every five minutes — not one per scan.
    if ((int) $row['stale'] === 1) {
        $touch = $conn->prepare("UPDATE api_tokens_tbl SET last_used_at = NOW() WHERE id = ?");
        $tokenId = (int) $row['token_id'];
        $touch->bind_param("i", $tokenId);
        $touch->execute();
        $touch->close();
    }

    return $row;
}

function api_token_revoke(mysqli $conn, string $token): void
{
    if ($token === '' || !api_tokens_ready($conn)) return;

    $hash = api_token_hash($token);
    $stmt = $conn->prepare("DELETE FROM api_tokens_tbl WHERE token_hash = ?");
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    $stmt->close();
}

/**
 * Signs this user out of the app on every phone. Called when their
 * password changes. Never throws: a password change must not fail
 * because the token table is missing.
 */
function api_tokens_revoke_user(mysqli $conn, int $userId): void
{
    try {
        if (!api_tokens_ready($conn)) return;

        $stmt = $conn->prepare("DELETE FROM api_tokens_tbl WHERE user_id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $stmt->close();
    } catch (Throwable $e) {
        error_log('api_tokens_revoke_user: ' . $e->getMessage());
    }
}
