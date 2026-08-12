<?php require_once __DIR__ . '/../includes/asset.php';
include __DIR__ . "/../includes/systemConfig.php"; ?>

<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<meta name="color-scheme" content="dark" />
<title><?php echo htmlspecialchars($systemAcronym); ?> Attendance Tracker</title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<!-- Bootstrap Icons — the same family used in headerQrGenerator.php
     and on the admin pages. Needed by the `bi bi-*` classes in the
     hero, the chips, and the stat boxes. -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
<link rel="stylesheet" href="<?= asset('css/style.css') ?>">
