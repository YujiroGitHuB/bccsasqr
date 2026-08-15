<?php require_once __DIR__ . '/asset.php';

/* Same prefix as includes/theme_head.php — index.php is at the root
   and sets $themeBase = ''; every other includer is one folder down
   and takes the default. */
$themeBase = isset($themeBase) ? $themeBase : '../';
?>
<!-- Floating theme switch for the pages that have no topbar: the QR
     generator, the scanner, the tracker, the daily attendance form,
     the student photo profile and the login page. The admin pages put the same control in
     the topbar instead (components/topBar.php).

     Bottom-LEFT on purpose: the AI widget's launcher is fixed to the
     bottom-right on several of these pages, and the two would sit on
     top of each other.

     Same id and the same script as the topbar version, so the two
     never drift apart. -->
<button class="tb-theme theme-floating" id="themeToggle" type="button"
        aria-label="Switch between light and dark" title="Switch theme">
    <i class="bi" aria-hidden="true"></i>
</button>
<script src="<?= asset($themeBase . 'assets/js/theme.js') ?>"></script>
