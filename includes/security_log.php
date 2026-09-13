<?php
// ============================================================
// SECURITY EVENTS — a record of people trying things they
// should not.
//
// The attendance audit (includes/attendance_integrity.php) answers
// "who is holding the phone at the attendance form". Nothing
// answered the wider question: who is guessing passwords, who is
// calling an admin endpoint without being an admin, who is typing
// `' OR 1=1` into a student number box. Those requests were turned
// away correctly and left no trace, so an attack in progress looked
// exactly like a quiet day.
//
// This file only WATCHES. It never blocks a request and never
// changes a reply — prepared statements, permission guards and
// escaping are still what stop an attack. A detector that could
// refuse a request would one day refuse a real instructor over a
// false positive, and a log is not worth that.
//
// Read by pages/security_monitor.php.
// ============================================================

require_once __DIR__ . '/attendance_integrity.php';   // integrity_client_ip()

const SECURITY_LOG_DAYS = 30;

// Per source, per event, per 10 minutes. A script hammering the
// login form must not turn the 10 MB database into its diary — the
// first twenty rows already say everything the next thousand would.
const SECURITY_LOG_BURST = 20;

// Across every source, per hour. The per-source cap is useless
// against an attacker rotating IPs, so past this only high-severity
// events are still written.
const SECURITY_LOG_HOURLY = 600;

/**
 * Every event this file writes: [label, severity, icon].
 *
 * The page renders labels and colours from here, so a new event is
 * one line. An unknown key in the table still shows, as low.
 */
const SECURITY_EVENTS = [
    'probe'          => ['Attack pattern',    'high',   'bi-bug-fill'],
    'brute_force'    => ['Password guessing', 'high',   'bi-key-fill'],
    'face_mismatch'  => ['Forged face login', 'high',   'bi-person-bounding-box'],
    'access_denied'  => ['Blocked action',    'medium', 'bi-slash-circle'],
    'login_failed'   => ['Wrong password',    'medium', 'bi-x-octagon'],
    'login_disabled' => ['Disabled account',  'medium', 'bi-person-lock'],
    'cookie_forged'  => ['Tampered cookie',   'medium', 'bi-shield-exclamation'],
    'no_session'     => ['Not signed in',     'low',    'bi-door-closed'],
    'login_no_user'  => ['Unknown email',     'low',    'bi-envelope-x'],
];

/** [label, severity, icon] for an event key. */
function security_event_meta(string $event): array
{
    return SECURITY_EVENTS[$event] ?? [ucfirst(str_replace('_', ' ', $event)), 'low', 'bi-question-circle'];
}

/**
 * The shared mysqli — the same lookup as permissionsConn(), because
 * a guard can fire before the page has opened its connection.
 */
function security_conn(): ?mysqli
{
    foreach (['__bcc_conn', 'conn'] as $name) {
        if (isset($GLOBALS[$name]) && $GLOBALS[$name] instanceof mysqli) {
            return $GLOBALS[$name];
        }
    }

    include __DIR__ . '/db_connect.php';

    return isset($GLOBALS['__bcc_conn']) && $GLOBALS['__bcc_conn'] instanceof mysqli
        ? $GLOBALS['__bcc_conn']
        : null;
}

/**
 * Creates the table when it is missing.
 *
 * The attendance audit waited for someone to run its migration, and
 * for that whole time it recorded nothing. A monitor that is silent
 * until a manual step is exactly the gap this file exists to close,
 * so it installs itself. migrations/2026-09-13_add_security_events.sql
 * carries the same statement for the record — keep the two in step.
 */
function security_install(mysqli $conn): bool
{
    try {
        $conn->query("
            CREATE TABLE IF NOT EXISTS security_events_tbl (
                id         INT(11)      NOT NULL AUTO_INCREMENT,
                created_at DATETIME     NOT NULL DEFAULT current_timestamp(),
                event      VARCHAR(24)  NOT NULL,
                severity   VARCHAR(8)   NOT NULL,
                ip         VARCHAR(45)  DEFAULT NULL,
                user_id    INT(11)      DEFAULT NULL,
                identifier VARCHAR(120) DEFAULT NULL,
                path       VARCHAR(160) DEFAULT NULL,
                detail     VARCHAR(255) DEFAULT NULL,
                user_agent VARCHAR(255) DEFAULT NULL,
                PRIMARY KEY (id),
                KEY idx_created  (created_at),
                KEY idx_ip_event (ip, event, created_at),
                KEY idx_severity (severity, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ");
        return true;
    } catch (Throwable $e) {
        error_log('security_install: ' . $e->getMessage());
        return false;
    }
}

/**
 * Writes one event. Never throws, never stops the request.
 *
 * @param array $o  identifier — what was aimed at (an email, a permission, a pattern)
 *                  detail     — one sentence for the person reading the log
 *                  user_id    — defaults to whoever is signed in
 */
function security_log(string $event, array $o = []): void
{
    // One row per event and target per request: a probe spread over
    // six form fields is one attempt, not six.
    static $written = [];
    $once = $event . '|' . ($o['identifier'] ?? '');
    if (isset($written[$once])) return;
    $written[$once] = true;

    $conn = security_conn();
    if (!$conn) return;

    [, $severity] = security_event_meta($event);

    $ip         = integrity_client_ip();
    $userId     = $o['user_id'] ?? (isset($_SESSION['user_id']) ? (int) $_SESSION['user_id'] : null);
    $identifier = mb_substr((string) ($o['identifier'] ?? ''), 0, 120) ?: null;
    $detail     = mb_substr((string) ($o['detail'] ?? ''), 0, 255) ?: null;
    $path       = mb_substr((string) parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH), 0, 160) ?: null;
    $userAgent  = mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255) ?: null;

    for ($attempt = 0; $attempt < 2; $attempt++) {
        try {
            $cap = $conn->prepare("
                SELECT COALESCE(SUM(ip = ? AND event = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)), 0) AS mine,
                       COUNT(*) AS hour
                FROM security_events_tbl
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
            ");
            $cap->bind_param("ss", $ip, $event);
            $cap->execute();
            $seen = $cap->get_result()->fetch_assoc();
            $cap->close();

            if ((int) $seen['mine'] >= SECURITY_LOG_BURST) return;
            if ((int) $seen['hour'] >= SECURITY_LOG_HOURLY && $severity !== 'high') return;

            $ins = $conn->prepare("
                INSERT INTO security_events_tbl
                    (event, severity, ip, user_id, identifier, path, detail, user_agent)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $ins->bind_param("sssissss", $event, $severity, $ip, $userId, $identifier, $path, $detail, $userAgent);
            $ins->execute();
            $ins->close();
            break;

        } catch (Throwable $e) {
            // 1146 = table does not exist. Install once and retry;
            // anything else is logged to the PHP error log and dropped.
            if ($attempt === 0 && (int) $e->getCode() === 1146 && security_install($conn)) {
                continue;
            }
            error_log('security_log: ' . $e->getMessage());
            return;
        }
    }

    // Occasional sweep, after the insert — same pattern as the
    // attendance audit.
    if (random_int(1, 100) === 1) {
        try {
            $conn->query("
                DELETE FROM security_events_tbl
                WHERE created_at < DATE_SUB(NOW(), INTERVAL " . SECURITY_LOG_DAYS . " DAY)
            ");
        } catch (Throwable $e) {
            // Nothing to sweep yet.
        }
    }
}

/**
 * A permission guard said no.
 *
 * Without a session it is someone calling an endpoint directly
 * without signing in; with one it is a signed-in user reaching past
 * what they were given. The second is the more interesting of the
 * two, so it is the one marked medium.
 */
function security_denied(string $what): void
{
    $signedIn = !empty($_SESSION['user_id']);

    security_log($signedIn ? 'access_denied' : 'no_session', [
        'identifier' => $what,
        'detail'     => $signedIn
            ? 'Tried to use something this account has not been given.'
            : 'Called a protected page without being signed in.',
    ]);
}

/**
 * A sign-in failed. Logs it, then escalates once the failures from
 * this source — or against this email — look like guessing.
 *
 * Five in fifteen minutes. A person who forgot their password tries
 * two or three variations and stops; a list does not stop.
 */
function security_failed_login(string $event, string $email): void
{
    security_log($event, [
        'identifier' => $email,
        'detail'     => $event === 'login_no_user'
            ? 'Sign-in with an email that has no account.'
            : ($event === 'login_disabled'
                ? 'Sign-in to an account that has been disabled.'
                : 'Sign-in with the wrong password.'),
    ]);

    $conn = security_conn();
    if (!$conn) return;

    $ip = integrity_client_ip();

    try {
        $stmt = $conn->prepare("
            SELECT COUNT(*) AS fails,
                   COUNT(DISTINCT identifier) AS emails,
                   (SELECT COUNT(*) FROM security_events_tbl
                     WHERE event = 'brute_force' AND (ip = ? OR identifier = ?)
                       AND created_at >= DATE_SUB(NOW(), INTERVAL 15 MINUTE)) AS flagged
            FROM security_events_tbl
            WHERE event IN ('login_failed', 'login_no_user', 'login_disabled')
              AND (ip = ? OR identifier = ?)
              AND created_at >= DATE_SUB(NOW(), INTERVAL 15 MINUTE)
        ");
        $stmt->bind_param("ssss", $ip, $email, $ip, $email);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
    } catch (Throwable $e) {
        return;
    }

    // One brute_force row per quarter hour, not one per extra guess.
    if ((int) $row['fails'] >= 5 && (int) $row['flagged'] === 0) {
        security_log('brute_force', [
            'identifier' => $email,
            'detail'     => (int) $row['fails'] . ' failed sign-ins in 15 minutes'
                          . ((int) $row['emails'] > 1 ? ', across ' . (int) $row['emails'] . ' emails' : '')
                          . '.',
        ]);
    }
}

/**
 * Looks through the request for the shapes of common attacks.
 *
 * Called once per request from includes/db_connect.php — the one
 * file every endpoint, public or signed-in, already loads.
 *
 * The patterns are deliberately narrow. A student named O'Neil, an
 * instructor's note that says "#1 in class", a colour like "#0ea5e9"
 * must never land here; a false alarm on every other page teaches
 * the admin to stop reading the log. Each pattern needs a keyword or
 * a character sequence ordinary typing does not produce.
 */
function security_scan_request(): void
{
    static $done = false;
    if ($done || PHP_SAPI === 'cli') return;
    $done = true;

    $patterns = [
        'SQL injection' => [
            '/\bunion\b(?:\s|\/\*.*?\*\/)+(?:all\s+)?select\b/i',
            '/\'\s*(?:or|and|\|\||&&)\s+[\'"]?\w+[\'"]?\s*(?:=|like)\s*[\'"]?\w/i',
            '/\b(?:or|and)\s+(\d+)\s*=\s*\1\b/i',
            '/\b(?:sleep|benchmark|pg_sleep)\s*\(\s*\d/i',
            '/\bwaitfor\s+delay\b/i',
            '/\binformation_schema\b|\bload_file\s*\(|\binto\s+(?:out|dump)file\b/i',
            '/;\s*(?:drop\s+table|truncate\s+table|delete\s+from|insert\s+into|update\s+\w+\s+set)\b/i',
            // admin'-- : a quote, then a comment that ends the value.
            // Anchored to the end so "Class 'A' #2" in a note is left alone.
            '/\'\s*(?:--|#|\/\*)\s*$/',
        ],
        'Script injection' => [
            '/<\s*script\b/i',
            '/\b(?:javascript|vbscript)\s*:/i',
            '/<[a-z][^>]*\son[a-z]{3,}\s*=/i',
            '/<\s*(?:iframe|object|embed)\b/i',
            '/\bdocument\.cookie\b/i',
        ],
        'Path traversal' => [
            '/\.\.[\/\\\\]/',
            '/%2e%2e|%252e|%00/i',
            '/\/etc\/passwd|\bwin\.ini\b|\bboot\.ini\b/i',
        ],
        'Code injection' => [
            '/<\?(?:php|=)/i',
            '/\$\{jndi:/i',
            '/\b(?:shell_exec|passthru|phpinfo|base64_decode)\s*\(/i',
        ],
    ];

    // Fields that legitimately hold odd bytes: passwords (anything
    // goes), face descriptors (JSON of floats), images (base64).
    $skip = '/pass|descriptor|photo|image|selfie|signature|token/i';

    $hits = [];
    $walk = function (array $data, string $prefix) use (&$walk, &$hits, $patterns, $skip): void {
        foreach ($data as $key => $value) {
            $field = $prefix === '' ? (string) $key : $prefix . '[' . $key . ']';

            if (preg_match($skip, (string) $key)) continue;
            if (is_array($value)) { $walk($value, $field); continue; }
            if (!is_string($value) || $value === '' || strlen($value) > 4096) continue;

            // Decoded once more: `%27%20OR%201%3D1` arrives already
            // decoded, but a double-encoded payload does not.
            $candidates = array_unique([$value, rawurldecode($value)]);

            foreach ($patterns as $kind => $list) {
                if (isset($hits[$kind])) continue;
                foreach ($list as $re) {
                    foreach ($candidates as $c) {
                        if (preg_match($re, $c)) {
                            $hits[$kind] = [$field, $value];
                            continue 3;
                        }
                    }
                }
            }
        }
    };

    $walk($_GET, '');
    $walk($_POST, '');

    foreach ($hits as $kind => [$field, $value]) {
        // Control characters out, and short: the value is shown on a
        // page, and a 4 KB payload in a table cell helps nobody.
        $snippet = preg_replace('/[\x00-\x1F\x7F]+/', ' ', $value);
        security_log('probe', [
            'identifier' => $kind,
            'detail'     => $field . ' = ' . mb_substr($snippet, 0, 180),
        ]);
    }

    // Attack tools that announce themselves. The host's JavaScript
    // challenge turns most of them away before PHP runs, so one that
    // gets through is worth a row.
    $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
    if ($ua !== '' && preg_match('/\b(sqlmap|nikto|nmap|masscan|acunetix|wpscan|dirbuster|gobuster|nuclei|hydra|zgrab|havij|w3af)\b/i', $ua, $m)) {
        security_log('probe', [
            'identifier' => 'Scanner tool',
            'detail'     => 'User agent names ' . $m[1] . '.',
        ]);
    }
}
