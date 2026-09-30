<?php
// ============================================================
// How a page looks when its link is pasted into Messenger, a group
// chat or Facebook: the title, the line under it, and the picture.
//
// Without these tags the preview is guessed. The chat app took the
// <title>, then the first text it could find for the line under it —
// which, on every page, is the inline theme script at the top of the
// <head> (includes/theme_head.php). An attendance link sent to a
// class read "Online Attendance Forms (function () { try { var saved
// = localStorage.getItem('bcc-theme'); …".
//
// Call share_meta([...]) in the <head>, before theme_head.php, on any
// page whose link gets sent around. Everything is plain text; it is
// escaped here.
// ============================================================

/** https://host/bccsasqr — the project root as a URL, from any page. */
function share_site_url(): string
{
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';

    // How many folders below the project root the running page sits:
    // pages/x.php is one, index.php none. That many steps up from the
    // page's URL folder is the root's URL, whatever subfolder the host
    // puts the project in.
    $root   = str_replace('\\', '/', (string) realpath(dirname(__DIR__)));
    $script = str_replace('\\', '/', (string) realpath(dirname($_SERVER['SCRIPT_FILENAME'] ?? '')));
    $below  = strpos($script, $root) === 0 ? trim(substr($script, strlen($root)), '/') : '';
    $depth  = $below === '' ? 0 : substr_count($below, '/') + 1;

    $path = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/'));
    if ($depth > 0) {
        $path = str_replace('\\', '/', dirname($path, $depth));
    }
    $path = rtrim($path, '/.');

    return ($https ? 'https' : 'http') . '://' . $host . $path;
}

/**
 * Prints the tags. $o:
 *   title        — the preview's heading
 *   description  — the line under it
 *   image        — optional, a path from the project root; the school
 *                  logo from Settings when left out
 */
function share_meta(array $o): void
{
    $site  = share_site_url();
    $scheme = strpos($site, 'https://') === 0 ? 'https' : 'http';
    $url   = $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . ($_SERVER['REQUEST_URI'] ?? '/');

    // The logo uploaded in Settings — systemConfig.php reads it once per
    // request, so loading it here costs nothing on a page that loads it
    // later anyway. The seal in the repo when that file is missing.
    if (!isset($GLOBALS['__bcc_system'])) {
        include __DIR__ . '/systemConfig.php';
    }
    $image = ltrim((string) ($o['image'] ?? ($GLOBALS['__bcc_system']['logo'] ?? '')), '/');
    if ($image === '' || !is_file(dirname(__DIR__) . '/' . $image)) {
        $image = 'assets/images/bcc-logo.png';
    }

    $e = static fn($v): string => htmlspecialchars(trim((string) $v), ENT_QUOTES, 'UTF-8');
    $title       = $e($o['title'] ?? 'BCC SASQR');
    $description = $e($o['description'] ?? '');
    ?>
    <meta name="description" content="<?= $description ?>">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="BCC SASQR">
    <meta property="og:title" content="<?= $title ?>">
    <meta property="og:description" content="<?= $description ?>">
    <meta property="og:url" content="<?= $e($url) ?>">
    <meta property="og:image" content="<?= $e($site . '/' . str_replace(' ', '%20', $image)) ?>">
    <meta property="og:image:alt" content="Binalatongan Community College seal">
    <meta name="twitter:card" content="summary">
    <?php
}
