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
     index.php and reg.php — the two includers that sit AT the web
     root and so pass $themeBase = '' rather than the default '../'.

     reg.php was the last holdout: it wrote its own <head>, never
     loaded the tokens, and stayed dark whatever the user had picked.
     It follows the theme now like everything else — see the note at
     the top of assets/css/reg.css. -->
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
