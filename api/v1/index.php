<?php
// ============================================================
//  api/v1/index.php — the front door of the QR generator API.
//
//  Isang file lang ang pinapasok ng lahat ng tawag, para iisa ang
//  lugar ng CORS, ng susi, ng koneksyon at ng hugis ng sagot. Ang
//  mga handler sa ibaba ang may alam sa mga panuntunan; ang router
//  ay may alam lamang sa daan.
//
//  Base URL (pumili ng bumubuhay sa host mo):
//    https://…/api/v1/students/019-464             — may .htaccess
//    https://…/api/v1/index.php/students/019-464   — walang rewrite
//    https://…/api/v1/index.php?path=students/019-464
// ============================================================

require_once __DIR__ . '/lib/http.php';

// Optional and gitignored — it is where ALLOWED_ORIGIN and, if the
// owner wants one, MOBILE_API_KEY live. A missing file just means the
// defaults apply, never a broken API.
if (file_exists(__DIR__ . '/../../includes/config.php')) {
    require_once __DIR__ . '/../../includes/config.php';
}

// Headers, the CORS preflight, and the net that turns a fatal error
// into JSON. Everything below this line is safe to fail.
api_boot();
api_require_key();

require_once __DIR__ . '/lib/rate_limit.php';
include __DIR__ . '/../../includes/db_connect.php';   // provides $conn

require_once __DIR__ . '/lib/generator.php';
require_once __DIR__ . '/handlers/system.php';
require_once __DIR__ . '/handlers/students.php';
require_once __DIR__ . '/handlers/terms.php';

$path   = api_path();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// method, pattern, handler. The pattern is matched against the path
// with no leading or trailing slash.
$routes = [
    ['GET',  '#^$#',                       fn() => handle_index()],
    ['GET',  '#^health$#',                 fn() => handle_health($GLOBALS['conn'])],
    ['GET',  '#^config$#',                 fn() => handle_config($GLOBALS['conn'])],
    ['GET',  '#^terms$#',                  fn() => handle_terms()],
    ['POST', '#^terms/accept$#',           fn() => handle_terms_accept($GLOBALS['conn'])],
    ['GET',  '#^students/([^/]+)/qr$#',    fn($m) => handle_student_qr($GLOBALS['conn'], $m[1])],
    ['GET',  '#^students/([^/]+)$#',       fn($m) => handle_student($GLOBALS['conn'], $m[1])],
];

// Collected while matching so a wrong verb on a real route answers
// 405 with an Allow header, instead of a 404 that sends the client
// hunting for a typo in a URL that is perfectly correct.
$allowed = [];

foreach ($routes as [$verb, $pattern, $handler]) {
    if (!preg_match($pattern, $path, $m)) {
        continue;
    }

    if ($verb !== $method) {
        $allowed[] = $verb;
        continue;
    }

    $handler($m);   // every handler ends in api_ok()/api_fail(), which exit
    exit;
}

if ($allowed) {
    $allowed[] = 'OPTIONS';
    header('Allow: ' . implode(', ', array_unique($allowed)));
    api_fail(405, 'method_not_allowed', 'That endpoint does not accept ' . $method . ' requests.', [
        'allowed' => array_values(array_unique($allowed)),
    ]);
}

api_fail(404, 'not_found', 'No such endpoint.', [
    'path' => $path,
    'docs' => api_base_url() . '/api/v1',
]);
