<?php require_once __DIR__ . '/../includes/asset.php'; ?>

<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<meta name="color-scheme" content="dark" />
<title><?php echo $systemAcronym; ?> Code Generator</title>
<link rel="icon" type="image/png" href="../<?php echo $systemLogo; ?>">
<!-- Bootstrap Icons — ginagamit ng pahina ang mga `bi bi-*` na
     klase (mga tagubilin, hero, header ng Terms, at ang padlock sa
     mga naka-lock na patlang) pero hindi ito kailanman naka-link
     dito, kaya walang lumalabas na icon kahit isa. -->
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
<link rel="stylesheet" href="<?= asset('../QRgenerator/css/style.css') ?>">
<link rel="stylesheet" href="<?= asset('../assets/css/widget.css') ?>">
