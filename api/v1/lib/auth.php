<?php
// ============================================================
//  api/v1/lib/auth.php
//
//  Who is calling, for the endpoints that need to know.
//
//  The generator endpoints are open — students never sign in, on the
//  web or in the app. The scanner endpoints are not: they record
//  attendance under an instructor's name, exactly as the web scanner
//  does behind its session. The app signs in once (POST /auth/login),
//  keeps the token it gets back, and sends it on every scanner call:
//
//      X-Auth-Token: <64 hex characters>
//
//  A header of our own rather than Authorization: shared hosts running
//  PHP as CGI often drop Authorization before PHP sees it, and an app
//  that is signed out on every request for no visible reason is a
//  miserable thing to debug from a phone. Authorization: Bearer is
//  still accepted for clients that prefer it.
// ============================================================

require_once __DIR__ . '/../../../includes/api_tokens.php';
require_once __DIR__ . '/../../../includes/permissions.php';
require_once __DIR__ . '/../../../includes/security_log.php';

/** The token the caller sent, or '' when there is none worth looking up. */
function api_auth_token(): string
{
    $sent = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';

    if ($sent === '') {
        $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if (is_string($auth) && preg_match('/^Bearer\s+(\S+)$/i', $auth, $m)) {
            $sent = $m[1];
        }
    }

    // Anything but the shape api_token_issue() hands out is not worth
    // a database round trip.
    return is_string($sent) && preg_match('/^[a-f0-9]{64}$/', $sent) ? $sent : '';
}

/**
 * The signed-in account, or a 401 the app answers by showing the
 * sign-in screen again.
 */
function api_require_user(mysqli $conn): array
{
    $token = api_auth_token();
    $user  = $token !== '' ? api_token_user($conn, $token) : null;

    if (!$user) {
        api_fail(401, 'unauthenticated', 'Your sign-in has expired. Please sign in again.');
    }

    return $user;
}

/**
 * can() for a token instead of a session: admins always may, everyone
 * else needs the row in user_permissions_tbl. Read fresh per request,
 * so unticking a box in Manage Access reaches the phone on its next
 * call.
 */
function api_user_can(array $user, string $permission): bool
{
    if (($user['role'] ?? '') === 'admin') {
        return true;
    }

    return in_array($permission, userPermissions((int) $user['id']), true);
}

function api_require_permission(array $user, string $permission, string $message): void
{
    if (api_user_can($user, $permission)) {
        return;
    }

    security_log('access_denied', [
        'identifier' => $permission,
        'user_id'    => (int) $user['id'],
        'detail'     => 'Tried to use something this account has not been given (phone app).',
    ]);

    api_fail(403, 'forbidden', $message, ['permission' => $permission]);
}

/** What the app is told about the signed-in account. */
function api_user_resource(array $user): array
{
    return [
        'id'         => (int) $user['id'],
        'name'       => (string) $user['name'],
        'email'      => (string) $user['email'],
        'role'       => (string) $user['role'],
        'avatar_url' => api_asset_url($user['avatar'] ?? null),
        // Whether the app shows the Links tab. Read fresh on every call
        // that returns the user, like every other permission here.
        'can_manage_links' => api_user_can($user, 'links.manage'),
    ];
}
