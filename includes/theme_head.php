<?php require_once __DIR__ . '/asset.php';

/* Where the including page sits relative to the project root. Pages
   one folder down (the QR generator, scanner, tracker, pages/…) take
   the default; index.php sits AT the root and sets $themeBase = ''
   before including this. Without it the link would resolve above the
   web root and the tokens would silently never load. */
$themeBase = isset($themeBase) ? $themeBase : '../';
?>
<!-- Theme, resolved BEFORE any stylesheet loads.

     Inline and blocking on purpose: read from an external file this
     would run after the first paint, and every page would flash the
     wrong colour before correcting itself.

     `data-theme` drives assets/css/theme.css; `data-bs-theme` drives
     Bootstrap's own components (form controls, dropdowns, tables),
     which have no media-query mode of their own and must be told
     explicitly.

     Shared by includes/header.php (admin pages), by the QR generator,
     scanner, tracker and student photo profile heads, and by
     index.php — which passes $themeBase = '' because it is the one
     includer that is not a directory below the root.

     NOT included by reg.php: registration is still a full-bleed dark
     hero and stays dark in both themes. The login page used to be the
     same; it now follows the theme like the rest of the app — see the
     note at the top of assets/css/login.css. -->
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
<link rel="stylesheet" href="<?= asset($themeBase . 'assets/css/theme.css') ?>">
