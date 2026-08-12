<?php
// The visible footer, shared by the sidebar (every admin page), the
// login page, the QR generator, the QR scanner, the tracker, the
// daily attendance page, and the student photo profile.
//
// Self-sufficient on purpose: index.php and
// student/StudentPhotoProfile.php include this WITHOUT having pulled
// in a header first, so the values cannot be assumed to be in scope.
// systemConfig.php caches its row in $GLOBALS, so this include is
// free on pages that already have one.
if (!isset($footerOrg)) {
    include __DIR__ . "/../includes/systemConfig.php";
}

// The URL is typed by an admin and lands in an href, so a
// `javascript:` value would run on every page of the site. It is
// validated on save (crud/update_system_config.php) — this second
// check is here because a row edited straight in phpMyAdmin never
// passes through that.
$footerLink = '';
if (!empty($footerDeveloperUrl)) {
    $scheme = strtolower((string) parse_url($footerDeveloperUrl, PHP_URL_SCHEME));
    if ($scheme === 'http' || $scheme === 'https') {
        $footerLink = $footerDeveloperUrl;
    }
}
?>
<footer style="
    background-color: transparent;
    color: #fff;
    text-align: center;
    padding: 15px 10px;
    font-size: 0.9rem;
    margin-top: 30px;
">
    <?php if ($footerOrg !== ''): ?>
        &copy; <?= htmlspecialchars($footerYear) ?> <?= htmlspecialchars($footerOrg) ?>. All rights reserved.
    <?php endif; ?>

    <?php if ($footerDeveloper !== ''): ?>
        <?php if ($footerOrg !== ''): ?><br><?php endif; ?>
        Developed by
        <?php if ($footerLink !== ''): ?>
            <a href="<?= htmlspecialchars($footerLink) ?>" target="_blank" rel="noopener noreferrer"
               style="color: #38bdf8; text-decoration: none;">
                <?= htmlspecialchars($footerDeveloper) ?>
            </a>
        <?php else: ?>
            <?= htmlspecialchars($footerDeveloper) ?>
        <?php endif; ?>
    <?php endif; ?>
</footer>
