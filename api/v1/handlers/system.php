<?php
// ============================================================
//  api/v1/handlers/system.php
//
//  The calls a Flutter app makes before it shows anything: is the
//  server alive, how should the screen be configured, what do the
//  terms say — and is there a newer app on the download page.
// ============================================================

require_once __DIR__ . '/../../../includes/app_release.php';

/** GET /api/v1 — a directory of what is here, for anyone poking with a browser. */
function handle_index(): void
{
    $base = api_base_url() . '/api/v1';

    api_ok([
        'name'      => 'BCC QR Attendance — QR Generator and Scanner API',
        'version'   => API_VERSION,
        'endpoints' => [
            'GET  ' . $base . '/health',
            'GET  ' . $base . '/config',
            'GET  ' . $base . '/app',
            'GET  ' . $base . '/terms',
            'POST ' . $base . '/terms/accept',
            'GET  ' . $base . '/students/{student_no}',
            'GET  ' . $base . '/students/{student_no}/qr',
            'GET  ' . $base . '/students/{student_no}/attendance',
            'POST ' . $base . '/students/{student_no}/verify',
            'POST ' . $base . '/students/{student_no}/photo',
            'POST ' . $base . '/auth/login',
            'POST ' . $base . '/auth/logout',
            'GET  ' . $base . '/auth/me',
            'GET  ' . $base . '/scanner/subjects',
            'POST ' . $base . '/scanner/scan',
            'GET  ' . $base . '/scanner/attendance',
            'POST ' . $base . '/scanner/late',
            'GET  ' . $base . '/scanner/roster',
            'POST ' . $base . '/scanner/sync',
            'GET  ' . $base . '/links',
            'POST ' . $base . '/links/expiry',
            'POST ' . $base . '/links/late',
            'POST ' . $base . '/links/renew',
            'GET  ' . $base . '/checkin/{code}',
            'POST ' . $base . '/checkin/{code}',
        ],
        'docs' => $base . '/README.md',
    ]);
}

/**
 * GET /api/v1/health
 *
 * Deliberately touches the database. A health check that only proves
 * PHP is running answers "yes" from a server where every real call
 * would fail.
 */
function handle_health(mysqli $conn): void
{
    $ok = (bool) $conn->query('SELECT 1');

    api_ok([
        'status'   => $ok ? 'ok' : 'degraded',
        'database' => $ok,
        'version'  => API_VERSION,
        // From MySQL, not PHP: the connection is pinned to +08:00 in
        // includes/db_connect.php and that is the clock every stored
        // timestamp in this API is measured against.
        'server_time' => $conn->query('SELECT NOW() AS now')->fetch_assoc()['now'] ?? null,
    ], $ok ? 200 : 503);
}

/**
 * GET /api/v1/config
 *
 * Everything the app would otherwise hardcode: the school's name and
 * logo, the student-number format, the QR's drawing spec, and whether
 * the generator is switched off right now.
 *
 * Fetch this at startup. Every value here can be changed by an admin
 * in Settings without shipping a new build of the app.
 */
function handle_config(mysqli $conn): void
{
    include __DIR__ . '/../../../includes/systemConfig.php';

    $locked = gen_is_locked($conn);

    api_ok([
        'system' => [
            'name'     => $systemName,
            'acronym'  => $systemAcronym,
            'logo_url' => api_asset_url($systemLogo),
        ],
        'generator' => [
            // The web page swaps itself for includes/lock.php when
            // this is true; the app should show the same closed sign
            // instead of a form that cannot submit.
            'locked'  => $locked,
            'message' => $locked
                ? 'The QR generator is temporarily closed. Please try again later.'
                : null,
            'student_no' => [
                // Handed over as a string so Dart can build its own
                // RegExp from it and stay in step with the server.
                'pattern' => trim(GEN_STUDENT_NO_PATTERN, '/'),
                'example' => GEN_STUDENT_NO_EXAMPLE,
                'hint'    => 'Use YEAR-NUMBER, e.g. ' . GEN_STUDENT_NO_EXAMPLE . '.',
            ],
        ],
        'qr' => gen_qr_spec(),
        'terms' => [
            'version'  => TERMS_VERSION,
            'required' => true,
            'url'      => api_base_url() . '/api/v1/terms',
        ],
        'photo' => [
            'required' => photo_is_required($conn),
            'note'     => 'A photo is not needed to generate a QR, but attendance may be refused without one.',
        ],
        'footer' => [
            'org'           => $footerOrg,
            'developer'     => $footerDeveloper,
            'developer_url' => $footerDeveloperUrl,
            'year'          => $footerYear,
        ],
    ]);
}

/**
 * GET /api/v1/app
 *
 * The Android app on the download page, read from the uploaded APK
 * (includes/app_release.php), and the oldest build still allowed to
 * run. The app asks when it starts and when it comes back to the
 * screen: a newer `latest.build` than its own is offered on Home, and
 * a build under `min_build` shows only "Update required".
 *
 * No sign-in and no database: it is asked by every phone, often, and
 * says nothing that is not on the download page already.
 */
function handle_app(): void
{
    $release = app_release();

    api_ok([
        // Null with no APK uploaded: nothing to offer.
        'latest' => $release === null ? null : [
            'version' => $release['version'],
            'build'   => $release['build'],
            'size'    => $release['size'],
            'updated' => date('c', $release['updated']),
        ],
        'min_build'    => APP_MIN_BUILD,
        'download_url' => api_base_url() . '/download/',
    ]);
}

/**
 * GET /api/v1/terms
 *
 * The same text the web modal shows, straight from
 * includes/terms.php — there is no second copy to keep in step, and
 * raising TERMS_VERSION there changes the app too.
 *
 * `html` is the authored version. `text` is a plain-text fallback for
 * a Flutter screen that would rather not pull in a HTML renderer.
 */
function handle_terms(): void
{
    $html = terms_body_html();

    // <h4> headings become their own paragraph rather than running
    // into the sentence beneath them.
    $text = preg_replace('#</(h4|p)>#i', "\n\n", $html);
    $text = html_entity_decode(strip_tags((string) $text), ENT_QUOTES, 'UTF-8');
    $text = trim(preg_replace("/\n{3,}/", "\n\n", preg_replace('/[ \t]+/', ' ', $text)));

    api_ok([
        'version' => TERMS_VERSION,
        'contact' => TERMS_CONTACT,
        'html'    => $html,
        'text'    => $text,
    ]);
}
