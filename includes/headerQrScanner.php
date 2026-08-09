<?php include __DIR__ . "/../includes/systemConfig.php"; ?>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title><?php echo $systemAcronym; ?> Scanner</title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<?php include("db_connect.php"); ?>
<!-- DataTables CSS & jQuery -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/jquery.dataTables.min.css">
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<link rel="stylesheet" href="css/style.css">