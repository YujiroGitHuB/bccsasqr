<?php require_once __DIR__ . '/../includes/asset.php';
 include __DIR__ . "/../includes/systemConfig.php";?>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?php echo $systemName; ?></title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<!-- DataTables Buttons CSS -->
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.dataTables.min.css">
<!-- DataTables Bootstrap 5 Theme -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<!-- Bootstrap 5 — dapat MANATILING pagkatapos ng DataTables theme.
     Dating dalawang beses naka-link ang Bootstrap (bago at pagkatapos
     ng theme). Ang huling kopya ang nananaig, kaya iyon ang itinira;
     kung ang naunang kopya ang itinira, ang DataTables theme na ang
     mananalo at magbabago ang hitsura ng mga talahanayan. -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
<!-- Icons -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="<?= asset('../assets/css/main.css') ?>">
<!-- Sidebar — pagkatapos ng main.css (para manaig sa mga lumang
     panuntunan doon) at bago ang mobile.css (na dapat manatiling
     huli para sa off-canvas na ayos sa telepono). -->
<link rel="stylesheet" href="<?= asset('../assets/css/sidebar.css') ?>">
<link rel="stylesheet" href="<?= asset('../assets/css/topbar.css') ?>">
<!-- Mobile/tablet layout — dapat MANATILING huli para manaig sa main.css -->
<link rel="stylesheet" href="<?= asset('../assets/css/mobile.css') ?>">