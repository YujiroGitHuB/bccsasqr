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
require_once __DIR__ . '/handlers/photos.php';
require_once __DIR__ . '/handlers/terms.php';
require_once __DIR__ . '/handlers/scanner.php';
require_once __DIR__ . '/handlers/tracker.php';
require_once __DIR__ . '/handlers/links.php';
require_once __DIR__ . '/handlers/checkin.php';
require_once __DIR__ . '/handlers/live.php';

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
    ['GET',  '#^students/([^/]+)/attendance$#', fn($m) => handle_student_attendance($GLOBALS['conn'], $m[1])],
    // The student's own photo — see handlers/photos.php.
    ['POST', '#^students/([^/]+)/verify$#', fn($m) => handle_student_verify($GLOBALS['conn'], $m[1])],
    ['POST', '#^students/([^/]+)/photo$#',  fn($m) => handle_student_photo($GLOBALS['conn'], $m[1])],
    // What is new on the student's record — see handlers/live.php.
    ['POST', '#^students/([^/]+)/live$#',   fn($m) => handle_student_live($GLOBALS['conn'], $m[1])],
    ['GET',  '#^students/([^/]+)$#',       fn($m) => handle_student($GLOBALS['conn'], $m[1])],

    // The scanner — signed in, see handlers/scanner.php.
    ['POST', '#^auth/login$#',             fn() => handle_auth_login($GLOBALS['conn'])],
    ['POST', '#^auth/logout$#',            fn() => handle_auth_logout($GLOBALS['conn'])],
    ['GET',  '#^auth/me$#',                fn() => handle_auth_me($GLOBALS['conn'])],
    ['GET',  '#^scanner/subjects$#',       fn() => handle_scanner_subjects($GLOBALS['conn'])],
    ['POST', '#^scanner/scan$#',           fn() => handle_scanner_scan($GLOBALS['conn'])],
    ['GET',  '#^scanner/attendance$#',     fn() => handle_scanner_attendance($GLOBALS['conn'])],
    ['POST', '#^scanner/late$#',           fn() => handle_scanner_late($GLOBALS['conn'])],
    ['GET',  '#^scanner/roster$#',         fn() => handle_scanner_roster($GLOBALS['conn'])],
    ['POST', '#^scanner/sync$#',           fn() => handle_scanner_sync($GLOBALS['conn'])],

    // Attendance links — the same sign-in, see handlers/links.php.
    ['GET',  '#^links$#',                  fn() => handle_links($GLOBALS['conn'])],
    ['POST', '#^links/expiry$#',           fn() => handle_links_expiry($GLOBALS['conn'])],
    ['POST', '#^links/late$#',             fn() => handle_links_late($GLOBALS['conn'])],
    ['POST', '#^links/renew$#',            fn() => handle_links_renew($GLOBALS['conn'])],

    // A student checking in through a link — no sign-in, see
    // handlers/checkin.php.
    ['GET',  '#^checkin/([^/]+)$#',        fn($m) => handle_checkin_link($GLOBALS['conn'], $m[1])],
    ['POST', '#^checkin/([^/]+)$#',        fn($m) => handle_checkin($GLOBALS['conn'], $m[1])],
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
