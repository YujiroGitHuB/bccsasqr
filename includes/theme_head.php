<?php require_once __DIR__ . '/asset.php'; ?>
<!-- Theme, resolved BEFORE any stylesheet loads.

     Inline and blocking on purpose: read from an external file this
     would run after the first paint, and every page would flash the
     wrong colour before correcting itself.

     `data-theme` drives assets/css/theme.css; `data-bs-theme` drives
     Bootstrap's own components (form controls, dropdowns, tables),
     which have no media-query mode of their own and must be told
     explicitly.

     Shared by includes/header.php (admin pages) and by the QR
     generator, scanner, tracker and student photo profile heads. All
     of those sit one directory below the project root, which is why
     the path can be a fixed "../".

     NOT included by index.php or reg.php: the login and registration
     pages are a full-bleed dark hero and stay dark in both themes —
     see the note at the top of assets/css/login.css. -->
<script>
    (function () {
        try {
            var saved = localStorage.getItem('bcc-theme');
            var theme = (saved === 'light' || saved === 'dark')
                ? saved
                : (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
            var root = document.documentElement;
            root.setAttribute('data-theme', theme);
            root.setAttribute('data-bs-theme', theme);
        } catch (e) {
            // Private mode can throw on localStorage. Dark is what the
            // app looked like before the theme existed.
            document.documentElement.setAttribute('data-theme', 'dark');
            document.documentElement.setAttribute('data-bs-theme', 'dark');
        }
    })();
</script>
<!-- Tokens first: every stylesheet below reads from them. -->
<link rel="stylesheet" href="<?= asset('../assets/css/theme.css') ?>">
