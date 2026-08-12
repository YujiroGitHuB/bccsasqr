<?php require_once __DIR__ . '/../includes/asset.php'; ?>

<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<meta name="color-scheme" content="dark" />
<title><?php echo $systemAcronym; ?> Code Generator</title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<!-- Bootstrap Icons — the page uses `bi bi-*` classes (the
     instructions, the hero, the Terms header, and the padlock on the
     locked fields) but this was never linked here, so not a single
     icon appeared. -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
<link rel="stylesheet" href="<?= asset('../QRgenerator/css/style.css') ?>">
<link rel="stylesheet" href="<?= asset('../assets/css/widget.css') ?>">
