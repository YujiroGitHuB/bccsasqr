<?php require_once __DIR__ . '/../includes/asset.php';
 include __DIR__ . "/../includes/systemConfig.php";?>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<?php include __DIR__ . "/theme_head.php"; ?>
<title><?php echo $systemName; ?></title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<!-- DataTables Bootstrap 5 Theme -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<!-- Bootstrap 5 — must STAY after the DataTables theme. Bootstrap used
     to be linked twice (before and after the theme). The last copy is
     the one that wins, so that is the one kept; keeping the earlier
     copy instead would let the DataTables theme win and change how the
     tables look. -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
<!-- Icons -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="<?= asset('../assets/css/main.css') ?>">
<!-- Sidebar — after main.css (to override the older rules there) and
     before mobile.css (which must stay last for the off-canvas phone
     layout). -->
<link rel="stylesheet" href="<?= asset('../assets/css/sidebar.css') ?>">
<link rel="stylesheet" href="<?= asset('../assets/css/topbar.css') ?>">
<!-- Mobile/tablet layout — must STAY last to override main.css -->
<link rel="stylesheet" href="<?= asset('../assets/css/mobile.css') ?>">