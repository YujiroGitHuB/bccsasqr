<?php
/*
 * ============================================================
 * Automatic cache-busting for local CSS and JS.
 *
 * The problem: browsers cache main.css and the scripts. When a CSS
 * fix is deployed, users still see the old one — especially on
 * phones, where the cache lives a long time. The old remedy was a
 * manual "?v=1.2", but that has to be remembered on every edit; when
 * it is forgotten, nothing appears to change.
 *
 * Here the file's last-modified time (filemtime) is the version. It
 * is used inside a PHP echo tag like this:
 *
 *     <link rel="stylesheet" href="{asset('../assets/css/main.css')}">
 *
 * and what it emits is:
 *
 *     ../assets/css/main.css?v=1770712345
 *
 * When the file changes the number changes and the browser fetches a
 * fresh copy on its own. When it does not, the cache stands — no
 * request is wasted.
 *
 * What gets passed in is the HREF exactly as written in the HTML
 * (including the "../"). The browser resolves such a path against
 * the page's URL, and its equivalent on disk is the folder of the
 * running script — which is why SCRIPT_FILENAME is the base. It
 * works at any depth (index.php, pages/…, Qrscanner/…).
 *
 * NOTE: never put a PHP closing tag inside a "//" comment here — it
 * ends PHP mode even inside a comment, and the function below would
 * no longer be read.
 * ============================================================
 */

if (!function_exists('asset')) {

    function asset(string $href): string
    {
        // stat each file once per request — some scripts are included
        // several times on a page.
        static $cache = [];

        if (isset($cache[$href])) {
            return $cache[$href];
        }

        // Strip any old "?v=…" still written in the HTML.
        $path = strtok($href, '?');

        $base = isset($_SERVER['SCRIPT_FILENAME'])
            ? dirname($_SERVER['SCRIPT_FILENAME'])
            : dirname(__DIR__);

        $mtime = @filemtime($base . '/' . $path);

        // When the file cannot be found (a different hosting setup,
        // say), return the original path — better no version than a
        // broken link.
        return $cache[$href] = $mtime ? $path . '?v=' . $mtime : $path;
    }
}
