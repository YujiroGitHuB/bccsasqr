<?php
// ============================================================
//  Attendance links, for the phone app's Links tab.
//
//    GET  /links          the Attendance Links page's list
//    POST /links/expiry   set, extend or remove when a link closes
//    POST /links/late     set or remove the late cutoff
//    POST /links/renew    a new code (a new URL) for the same class
//
//  The web page is pages/generate_attendance_link.php. Every rule —
//  which links exist, who may change one, what a time means — is in
//  includes/links.php and includes/late.php, which the page's own
//  endpoints (pages/get_links_ajax.php, crud/set_link_*.php,
//  crud/new_link_code.php) call too. This file only signs the caller
//  in and translates the answers into the API's envelope.
//
//  Signed in with the scanner's token (see lib/auth.php), and closed
//  to an account without "Manage attendance links" — the permission
//  the web page checks.
// ============================================================

require_once __DIR__ . '/../lib/auth.php';
require_once __DIR__ . '/../../../includes/links.php';

/** Signed in, and allowed to manage links. */
function links_guard(mysqli $conn): array
{
    $user = api_require_user($conn);

    api_require_permission($user, 'links.manage', 'Your account does not have access to attendance links. Please contact the administrator.');

    return $user;
}

/**
 * The address students open — the one the web page shows and puts in
 * its QR code: pages/daily_attendance.php?c=CODE.
 */
function links_url(string $short_code): string
{
    return api_base_url() . '/pages/daily_attendance.php?c=' . $short_code;
}

/**
 * A link's code, address, expiry and late cutoff, as the app reads
 * them. Every time is the database's: `in` is seconds from the
 * server's now (negative once passed), and the app only counts down
 * from it, as the web page does — the phone's clock never decides
 * whether a link is open.
 */
function links_state_resource(array $state): array
{
    return [
        'short_code' => (string) $state['short_code'],
        'url'        => links_url((string) $state['short_code']),
        'expiry'     => [
            'at'      => $state['expires_at'],
            'label'   => $state['expires_label'],
            'short'   => $state['expires_short'],
            'in'      => $state['expires_in'],
            'expired' => (bool) $state['is_expired'],
        ],
        'late'       => [
            'on'    => (bool) $state['late_on'],
            'in'    => $state['late_in'],
            'label' => $state['late_label'],
        ],
    ];
}

/** One card of the list: the state, plus whose class it is. */
function links_item_resource(array $link, bool $isAdmin): array
{
    $s = $link['subject'];

    return links_state_resource($link) + [
        'subject_code' => (string) $s['subject_code'],
        'subject_name' => (string) $s['subject_name'],
        'section'      => (string) $s['section'],
        'instructor'   => (string) $s['instructor_name'],
        // An instructor only ever sees their own.
        'mine'         => !$isAdmin || (int) ($s['is_mine'] ?? 0) === 1,
    ];
}

/**
 * The link named in the body, if this account may change it — or the
 * request ends here.
 */
function links_require_own(mysqli $conn, array $user, array $body): string
{
    $code = trim((string) (is_scalar($body['short_code'] ?? null) ? $body['short_code'] : ''));

    if ($code === '') {
        api_fail(400, 'missing_data', 'Short code required');
    }

    if (!link_owned($conn, $code, (int) $user['id'], ($user['role'] ?? '') === 'admin')) {
        api_fail(404, 'link_not_found', 'Link not found, or it is not yours to change.');
    }

    return $code;
}

/**
 * The time fields of a request, as link_expiry_clause() and
 * late_clause() read them from a web form. Scalars only: a JSON array
 * where a number belongs would otherwise reach trim() and end the
 * request in a PHP error instead of an answer.
 */
function links_time_input(array $body): array
{
    $in = [];
    foreach (['clear', 'preset', 'minutes', 'at'] as $key) {
        if (isset($body[$key]) && is_scalar($body[$key])) {
            $in[$key] = $body[$key];
        }
    }
    return $in;
}

/** GET /api/v1/links */
function handle_links(mysqli $conn): void
{
    $user    = links_guard($conn);
    $isAdmin = ($user['role'] ?? '') === 'admin';

    try {
        $result = links_for_user($conn, (int) $user['id'], (string) $user['role']);
        $links  = links_attach_state($conn, $result['links']);
    } catch (Throwable $e) {
        error_log('api links: ' . $e->getMessage());
        api_fail(500, 'links_failed', 'Could not load your attendance links. Please try again.');
    }

    api_ok([
        'admin'   => $isAdmin,
        'links'   => array_map(fn($l) => links_item_resource($l, $isAdmin), $links),
        // Links that expired on an earlier day and were given a new code
        // just now: the app says so, or the URL sent yesterday would
        // silently stop working.
        'rotated' => $result['rotated'],
    ]);
}

/**
 * POST /api/v1/links/expiry
 *   { "short_code": "K7M2QP", "minutes": 60 }      from now
 *   { "short_code": "K7M2QP", "preset": "eod" }    11:59 PM today
 *   { "short_code": "K7M2QP", "at": "2026-09-30T17:00" }
 *   { "short_code": "K7M2QP", "clear": true }
 */
function handle_links_expiry(mysqli $conn): void
{
    $user = links_guard($conn);
    $body = api_json_body();
    $code = links_require_own($conn, $user, $body);

    try {
        $done = link_set_expiry($conn, $code, links_time_input($body));
    } catch (Throwable $e) {
        error_log('api links/expiry: ' . $e->getMessage());
        api_fail(500, 'link_failed', 'Could not change the link. Please try again.');
    }

    if ($done['error'] !== null) {
        api_fail(422, 'not_changed', $done['error']);
    }

    api_ok(['link' => links_state_resource($done['state'])]);
}

/**
 * POST /api/v1/links/late
 *   { "short_code": "K7M2QP", "minutes": 15 }   on time for 15 more minutes
 *   { "short_code": "K7M2QP", "at": "08:15" }   on time until 8:15 today
 *   { "short_code": "K7M2QP", "clear": true }
 */
function handle_links_late(mysqli $conn): void
{
    $user = links_guard($conn);
    $body = api_json_body();
    $code = links_require_own($conn, $user, $body);

    try {
        $done = link_set_late($conn, $code, links_time_input($body));
    } catch (Throwable $e) {
        error_log('api links/late: ' . $e->getMessage());
        api_fail(500, 'link_failed', 'Could not change the link. Please try again.');
    }

    if ($done['error'] !== null) {
        api_fail(422, 'not_changed', $done['error']);
    }

    api_ok(['link' => links_state_resource($done['state'])]);
}

/**
 * POST /api/v1/links/renew   { "short_code": "K7M2QP" }
 *
 * The old URL and QR stop working at once. Takes the same optional
 * time fields as /links/expiry for the new link; without them it has
 * no expiry until one is set.
 */
function handle_links_renew(mysqli $conn): void
{
    $user = links_guard($conn);
    $body = api_json_body();
    $code = links_require_own($conn, $user, $body);

    try {
        $done = link_renew($conn, $code, links_time_input($body));
    } catch (Throwable $e) {
        error_log('api links/renew: ' . $e->getMessage());
        api_fail(500, 'link_failed', 'Could not issue a new link. Please try again.');
    }

    if ($done['error'] !== null) {
        api_fail(422, 'not_changed', $done['error']);
    }

    api_ok([
        'old_code' => $code,
        'link'     => links_state_resource($done['state']),
    ]);
}
