<?php
require_once __DIR__ . '/asset.php';
include __DIR__ . '/systemConfig.php';

/* ============================================================
   THE CLOSED SIGN.

   Included — and followed by exit — by QRgenerator/QRcode.php,
   Qrscanner/qrscanner.php, Tracker/view.php and reg.php when
   lock_settings_tbl says that page is switched off.

   Everything it looks like now lives in assets/css/lock.css;
   the page used to carry ~130 lines of dark-only CSS inline.
   ============================================================ */

/* How far the RUNNING script sits below the web root. reg.php is
   AT the root, the other three includers are one folder down, and
   the old file assumed "../" for everyone — so on the registration
   page the favicon pointed above the root and the tab came up
   blank. Worked out rather than assumed, so a fifth includer at
   any depth is correct without touching this. */
$__lockRoot = str_replace('\\', '/', dirname(__DIR__));
$__lockDir  = isset($_SERVER['SCRIPT_FILENAME'])
    ? str_replace('\\', '/', dirname($_SERVER['SCRIPT_FILENAME']))
    : $__lockRoot;
$__lockRel  = trim(substr($__lockDir, strlen($__lockRoot)), '/');
$lockBase   = $__lockRel === '' ? '' : str_repeat('../', substr_count($__lockRel, '/') + 1);

/* includes/theme_head.php and includes/theme_toggle.php both read
   this, defaulting to '../' when it is unset. */
$themeBase = $lockBase;

/* Which page the visitor was actually trying to reach. The lock is
   one file shared by four of them, and "Page" is a poor answer to
   "what is closed?" when the person scanned a QR code to get here.
   An includer may set $lockPageName itself; otherwise it is read
   from the running script. */
if (!isset($lockPageName)) {
    $__lockNames = [
        'QRcode.php'    => 'QR Generator',
        'qrscanner.php' => 'QR Scanner',
        'view.php'      => 'Attendance Tracker',
        'reg.php'       => 'Registration',
    ];
    $__lockScript = isset($_SERVER['SCRIPT_FILENAME'])
        ? basename($_SERVER['SCRIPT_FILENAME'])
        : '';
    $lockPageName = $__lockNames[$__lockScript] ?? '';
}

$lockHeading = $lockPageName === ''
    ? 'Page Temporarily Locked'
    : $lockPageName . ' Temporarily Locked';

$lockLogo = $lockBase . ($systemLogo ?: 'assets/images/default-logo.png');
$lockBrand = $systemAcronym && $systemAcronym !== 'None'
    ? $systemAcronym
    : ($systemName !== 'None' ? $systemName : 'BCC SAS QR');
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($lockHeading) ?></title>
    <!-- A page that exists only while a switch is flipped has no
         business in anyone's search results. -->
    <meta name="robots" content="noindex, nofollow">
    <link rel="icon" type="image/png" href="<?= htmlspecialchars($lockLogo) ?>">
    <?php include __DIR__ . '/theme_head.php'; ?>
    <link rel="stylesheet" href="<?= asset($lockBase . 'assets/css/lock.css') ?>">
</head>

<body class="lock-page">
    <main class="lock-card" role="alert">

        <div class="lock-brand">
            <span class="lock-seal">
                <img src="<?= htmlspecialchars($lockLogo) ?>" alt="">
            </span>
            <span class="lock-brand-name"><?= htmlspecialchars($lockBrand) ?></span>
        </div>

        <!-- Inline rather than an icon font: the page must render
             correctly even when it is the CDN that is having the bad
             day, and currentColor keeps the padlock on the same
             accent as the badge. -->
        <div class="lock-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"
                stroke-linecap="round" stroke-linejoin="round">
                <rect x="3.5" y="10.5" width="17" height="11" rx="2.5"></rect>
                <path d="M7.5 10.5V7a4.5 4.5 0 0 1 9 0v3.5"></path>
                <circle cx="12" cy="15.6" r="1.4"></circle>
                <path d="M12 17v1.8"></path>
            </svg>
        </div>

        <span class="lock-badge">Restricted</span>

        <h1><?= htmlspecialchars($lockHeading) ?></h1>

        <p class="lock-lede">
            This page is closed for maintenance or security reasons. Access
            usually returns shortly — nothing you did caused this.
        </p>

        <button class="lock-retry" type="button" id="lockRetry">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M21 12a9 9 0 1 1-3.2-6.9"></path>
                <path d="M21 3.5V9h-5.5"></path>
            </svg>
            Check again
        </button>

        <div class="lock-contact">
            <p class="lock-contact-label">Need access sooner? Reach the developer:</p>

            <div class="lock-actions">
                <!-- Messenger leads: it is the one that gets an answer
                     the same day. -->
                <a class="lock-btn is-primary" href="https://m.me/charlesnixon.cayading"
                    target="_blank" rel="noopener noreferrer">
                    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                        <path d="M12 2C6.3 2 2 6.2 2 11.7c0 3.1 1.4 5.9 3.7 7.7v3.1l3.4-1.9c.9.3 1.9.4 2.9.4 5.7 0 10-4.2 10-9.7S17.7 2 12 2zm1 12.6-2.5-2.7-4.9 2.7 5.4-5.7 2.6 2.7 4.8-2.7-5.4 5.7z" />
                    </svg>
                    Messenger
                </a>

                <a class="lock-btn is-secondary" href="https://www.facebook.com/charlesnixon.cayading"
                    target="_blank" rel="noopener noreferrer">
                    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                        <path d="M22 12.06C22 6.5 17.52 2 12 2S2 6.5 2 12.06c0 5 3.66 9.14 8.44 9.94v-7.03H7.9v-2.91h2.54V9.85c0-2.52 1.5-3.91 3.77-3.91 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.63.78-1.63 1.57v1.89h2.78l-.45 2.91h-2.33V22c4.78-.8 8.44-4.94 8.44-9.94z" />
                    </svg>
                    Facebook
                </a>
            </div>
        </div>

        <p class="lock-foot">
            <?php if ($footerOrg !== ''): ?>
                &copy; <?= htmlspecialchars($footerYear) ?> <?= htmlspecialchars($footerOrg) ?>
                <?php if ($footerDeveloper !== ''): ?>
                    &middot; Developed by
                    <?php if ($footerDeveloperUrl !== ''): ?>
                        <a href="<?= htmlspecialchars($footerDeveloperUrl) ?>" target="_blank"
                            rel="noopener noreferrer"><?= htmlspecialchars($footerDeveloper) ?></a>
                    <?php else: ?>
                        <?= htmlspecialchars($footerDeveloper) ?>
                    <?php endif; ?>
                <?php endif; ?>
            <?php else: ?>
                Thank you for your understanding.
            <?php endif; ?>
        </p>
    </main>

    <?php include __DIR__ . '/theme_toggle.php'; ?>

    <script>
        // A reload, not history.back() — the visitor may have arrived
        // from a QR scan with no page to go back to.
        document.getElementById('lockRetry').addEventListener('click', function () {
            location.reload();
        });
    </script>
</body>

</html>
