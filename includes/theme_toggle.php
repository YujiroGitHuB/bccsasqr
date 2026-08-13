<?php require_once __DIR__ . '/asset.php'; ?>
<!-- Floating theme switch for the pages that have no topbar: the QR
     generator, the scanner, the tracker, the daily attendance form and
     the student photo profile. The admin pages put the same control in
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
<script src="<?= asset('../assets/js/theme.js') ?>"></script>
