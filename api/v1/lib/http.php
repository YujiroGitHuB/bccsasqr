<?php
// ============================================================
//  api/v1/lib/http.php
//
//  The shared plumbing for every /api/v1 endpoint: one JSON shape,
//  one error shape, CORS, and the guard that keeps an HTML error
//  page from ever reaching a mobile client.
//
//  Ang bawat sagot ay may parehong balot:
//      { "success": true,  "data":  { ... } }
//      { "success": false, "error": { "code": "...", "message": "..." } }
//
//  Isang balot lang ang alam ng Flutter app — kaya kahit anong
//  endpoint ang tawagin nito, iisa ang paraan ng pagbasa.
// ============================================================

const API_VERSION = '1.0.0';

/**
 * Called once at the top of index.php.
 *
 * The shutdown handler is the important part. includes/db_connect.php
 * answers a dead database by including error.php — a full HTML page —
 * and then calling exit. A Flutter client asking for JSON would get
 * markup with a 200 on it and no way to tell what went wrong. The
 * buffer below catches that output and replaces it with a 503 the app
 * can actually branch on.
 */
function api_boot(): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: ' . (defined('ALLOWED_ORIGIN') ? ALLOWED_ORIGIN : '*'));
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-API-Key');
    header('Access-Control-Max-Age: 86400');

    // Student records change the moment an admin edits them; a cached
    // lookup would print a stale name on the card.
    header('Cache-Control: no-store');

    // A native Flutter client sends no preflight, but Flutter Web does.
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }

    $GLOBALS['__api_done'] = false;
    ob_start();

    register_shutdown_function(function () {
        if (!empty($GLOBALS['__api_done'])) {
            return;
        }

        // Nothing went through api_ok()/api_fail(), so either PHP died
        // or something included an HTML page and exited. Throw away
        // whatever it printed and answer in JSON.
        while (ob_get_level() > 0) {
            ob_end_clean();
        }

        $fatal   = error_get_last();
        $isFatal = $fatal && in_array($fatal['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true);

        http_response_code(503);
        echo json_encode([
            'success' => false,
            'error'   => [
                'code'    => 'service_unavailable',
                'message' => $isFatal
                    ? 'The server could not complete the request.'
                    : 'The service is temporarily unavailable. Please try again.',
            ],
        ]);
    });
}

/** A successful answer. Always exits. */
function api_ok(array $data, int $status = 200): void
{
    api_send($status, ['success' => true, 'data' => $data]);
}

/**
 * A failed answer. Always exits.
 *
 * `code` is the machine-readable half — the Flutter app switches on
 * it — and `message` is what may be shown to the student as-is.
 * `details` carries anything the app needs to act on the failure,
 * such as which requirement is still blocking a QR.
 */
function api_fail(int $status, string $code, string $message, array $details = []): void
{
    $error = ['code' => $code, 'message' => $message];
    if ($details) {
        $error['details'] = $details;
    }

    api_send($status, ['success' => false, 'error' => $error]);
}

function api_send(int $status, array $payload): void
{
    $GLOBALS['__api_done'] = true;

    while (ob_get_level() > 0) {
        ob_end_clean();
    }

    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * The route path, with or without pretty URLs.
 *
 * Three ways in, because the host decides which one works:
 *   /api/v1/students/019-464             (.htaccess rewrite)
 *   /api/v1/index.php/students/019-464   (PATH_INFO)
 *   /api/v1/index.php?path=students/019-464
 *
 * The last one is the fallback for shared hosting where mod_rewrite
 * is off and PATH_INFO is disabled — the app can be pointed at it
 * without touching server config.
 */
function api_path(): string
{
    $path = $_SERVER['PATH_INFO'] ?? '';

    if ($path === '') {
        $uri  = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '';
        $base = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '')), '/');

        if ($base !== '' && strpos($uri, $base) === 0) {
            $uri = substr($uri, strlen($base));
        }

        // Only the rewrite leaves a real route here; a plain hit on
        // index.php leaves "/index.php", which is not one.
        $path = preg_replace('#^/index\.php#', '', $uri) ?? '';
    }

    if (trim($path, '/') === '' && isset($_GET['path'])) {
        $path = (string) $_GET['path'];
    }

    return trim(rawurldecode($path), '/');
}

/** Absolute origin + project root, e.g. https://school.edu/bccsasqr */
function api_base_url(): string
{
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');

    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';

    // SCRIPT_NAME is /<root>/api/v1/index.php — two levels up from its
    // directory is the project root.
    $dir  = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    $root = rtrim(str_replace('\\', '/', dirname($dir, 2)), '/');
    if ($root === '.' || $root === '/') {
        $root = '';
    }

    return ($https ? 'https' : 'http') . '://' . $host . $root;
}

/** Turns a stored relative path (uploads/…, assets/…) into a URL the app can load. */
function api_asset_url(?string $path): ?string
{
    $path = trim((string) $path);
    if ($path === '') {
        return null;
    }
    if (preg_match('#^https?://#i', $path)) {
        return $path;
    }

    return api_base_url() . '/' . ltrim($path, '/');
}

/**
 * The JSON body of a POST, or a 400 if it is not JSON.
 *
 * form-encoded bodies are accepted too — Dart's http.post() sends one
 * when the Content-Type header is left off, and a silently empty body
 * is a miserable thing to debug from a phone.
 */
function api_json_body(): array
{
    $raw = file_get_contents('php://input');

    if (trim((string) $raw) === '') {
        return $_POST ?: [];
    }

    $data = json_decode($raw, true);

    if (!is_array($data)) {
        if ($_POST) {
            return $_POST;
        }
        api_fail(400, 'invalid_body', 'The request body must be a JSON object.');
    }

    return $data;
}

/**
 * Optional shared secret.
 *
 * Off by default: the QR generator has always been open to anyone who
 * can reach the page (see the comment at the top of
 * QRgenerator/QRcode.php), and the API is not stricter than the page
 * it mirrors. Define MOBILE_API_KEY in includes/config.php to require
 * an X-API-Key header — worth doing if this is reachable from the
 * public internet.
 */
function api_require_key(): void
{
    if (!defined('MOBILE_API_KEY') || MOBILE_API_KEY === '') {
        return;
    }

    $sent = $_SERVER['HTTP_X_API_KEY'] ?? ($_GET['api_key'] ?? '');

    if (!is_string($sent) || !hash_equals(MOBILE_API_KEY, $sent)) {
        api_fail(401, 'unauthorized', 'A valid X-API-Key header is required.');
    }
}

/** The caller's IP, as far as it can be trusted. */
function api_client_ip(): string
{
    return substr((string) ($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45);
}
