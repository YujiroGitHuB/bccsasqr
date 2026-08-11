<?php require_once __DIR__ . '/../includes/asset.php';
include __DIR__ . "/../includes/systemConfig.php"; ?>

<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<meta name="color-scheme" content="dark" />
<title><?php echo htmlspecialchars($systemAcronym); ?> Attendance Tracker</title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<!-- Bootstrap Icons — parehong pamilya ng ginagamit sa
     headerQrGenerator.php at sa mga admin page. Kailangan ito ng
     mga `bi bi-*` na klase sa hero, sa mga chip, at sa mga kahon
     ng bilang. -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
<link rel="stylesheet" href="<?= asset('css/style.css') ?>">
