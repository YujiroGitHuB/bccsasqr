<?php require_once __DIR__ . '/asset.php'; ?>
    <?php
    // The What's New dialog. Rendered here rather than on each page:
    // the button that opens it is in the topbar, and every page with
    // a topbar includes this footer, so neither has to be added
    // fourteen times. Its content is includes/whats_new.php.
    include __DIR__ . '/../components/whats_new_modal.php';
    ?>
    <!-- The theme is already applied by the inline script in
         header.php; this only wires the topbar toggle. Loaded here so
         every page with a topbar gets it without its own script tag. -->
    <script src="<?= asset('../assets/js/theme.js') ?>"></script>
    <script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
    <!-- Decides whether the topbar button shows an unread dot, and
         opens the dialog. After the Bootstrap bundle — it asks
         bootstrap.Modal to open it. -->
    <script src="<?= asset('../assets/js/whatsNew.js') ?>"></script>
    <!-- The DataTables Buttons stack (dataTables.buttons, buttons.html5,
         buttons.print) and its export dependencies (JSZip, pdfmake and
         vfs_fonts) used to load here on EVERY admin page. Nothing uses
         them any more — the Copy/CSV/Excel/PDF/Print bar was removed
         from assets/js/datatables.js. Reports are exported server-side
         through exports/export_pdf.php instead. -->