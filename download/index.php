<?php require_once __DIR__ . '/../includes/asset.php';

/* ============================================================
 * download/ — where students get the Android app.
 *
 * Public, like the QR generator: students do not log in.
 *
 * The APK itself is NOT in git. It is a 50 MB build artifact, and
 * a new one per release would bloat every clone forever. It is
 * uploaded by hand next to this file as download/BCC-SASQR.apk,
 * and deploy.yml excludes it so rsync --delete leaves it alone.
 * Everything the page says about the file — whether it exists, its
 * size, when it was updated — is read from the file itself, so the
 * page can never advertise a download that is not there.
 * ============================================================ */

include __DIR__ . '/../includes/systemConfig.php';

const APK_NAME = 'BCC-SASQR.apk';

$apkPath  = __DIR__ . '/' . APK_NAME;
$apkReady = is_file($apkPath);
$apkSize  = $apkReady ? filesize($apkPath) : 0;
$apkTime  = $apkReady ? filemtime($apkPath) : 0;

// The mtime in the URL: a phone that downloaded last week's build
// must not be handed its cached copy after an update.
$apkHref = APK_NAME . '?v=' . $apkTime;
$apkMb   = number_format($apkSize / 1048576, 1);
$apkDate = $apkReady ? date('M j, Y', $apkTime) : '';

$acronym = $systemAcronym !== 'None' ? $systemAcronym : 'BCC SASQR';

// The logo from Settings, unless its file is missing — which is not
// hypothetical: until deploy.yml learned to leave uploads alone, every
// push deleted it. The seal that ships with the code is the fallback,
// so the page never shows a broken image.
$logoFile = ltrim((string) $systemLogo, '/');
$logo     = '../' . (is_file(__DIR__ . '/../' . $logoFile) ? $logoFile : 'assets/images/bcc-logo.png');
?>
<!doctype html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Get the app · <?= htmlspecialchars($acronym) ?></title>
    <meta name="description" content="Download the <?= htmlspecialchars($acronym) ?> Android app and keep your attendance QR on your phone.">
    <link rel="icon" href="<?= htmlspecialchars($logo) ?>">

    <script>document.documentElement.classList.add('dl-js');</script>
    <?php include __DIR__ . '/../includes/theme_head.php'; ?>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="<?= asset('assets/download.css') ?>">

    <!-- In-app browser notice (assets/js/detection.js). It matters more
         here than anywhere: this link is shared in Messenger, and the
         Messenger/Facebook browser cannot download an APK at all. -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <link rel="stylesheet" href="<?= asset('../assets/css/detection.css') ?>">
</head>

<body class="dl-page">
    <!-- The room the scene stands in: two glows and a floor grid. -->
    <div class="dl-backdrop" aria-hidden="true">
        <div class="dl-glow is-a"></div>
        <div class="dl-glow is-b"></div>
        <div class="dl-floor"></div>
    </div>

    <header class="dl-nav">
        <a class="dl-brand" href="./">
            <img src="<?= htmlspecialchars($logo) ?>" alt="" width="34" height="34">
            <span><?= htmlspecialchars($acronym) ?></span>
        </a>
        <a class="dl-nav-link" href="../QRgenerator/QRcode.php">
            <i class="bi bi-globe2" aria-hidden="true"></i> Web generator
        </a>
    </header>

    <main class="dl-main">

        <!-- ══ HERO ══════════════════════════════════════════════ -->
        <section class="dl-hero">
            <div class="dl-hero-copy">
                <span class="dl-chip"><i class="bi bi-android2" aria-hidden="true"></i> Android app</span>

                <h1>Your attendance QR, <span class="dl-grad">in your pocket.</span></h1>

                <p class="dl-lead">
                    Look up your record, accept the terms once, and save the same
                    QR code the classroom scanner reads — right on your phone.
                </p>

                <div class="dl-cta">
                    <?php if ($apkReady): ?>
                        <a class="dl-btn primary" href="<?= htmlspecialchars($apkHref) ?>" download="<?= APK_NAME ?>">
                            <i class="bi bi-download" aria-hidden="true"></i>
                            <span>Download for Android</span>
                        </a>
                    <?php else: ?>
                        <!-- No file on the server yet: say so, instead of a
                             button that downloads a 404 page named .apk. -->
                        <span class="dl-btn primary is-off" aria-disabled="true">
                            <i class="bi bi-hourglass-split" aria-hidden="true"></i>
                            <span>Coming soon</span>
                        </span>
                    <?php endif; ?>
                    <a class="dl-btn ghost" href="../QRgenerator/QRcode.php">
                        <i class="bi bi-globe2" aria-hidden="true"></i>
                        <span>Use the web version</span>
                    </a>
                </div>

                <ul class="dl-meta">
                    <?php if ($apkReady): ?>
                        <li><i class="bi bi-file-earmark-zip" aria-hidden="true"></i> APK · <?= $apkMb ?> MB</li>
                        <li><i class="bi bi-clock-history" aria-hidden="true"></i> Updated <?= htmlspecialchars($apkDate) ?></li>
                    <?php endif; ?>
                    <li><i class="bi bi-phone" aria-hidden="true"></i> Android 7.0 or newer</li>
                </ul>

                <!-- A computer cannot install the app. Hand the page to the
                     phone instead of making the student type the URL. -->
                <div class="dl-handoff">
                    <div class="dl-handoff-code" id="handoffCode"></div>
                    <p>
                        <strong>On a computer?</strong>
                        Scan this with your phone's camera to open this page there.
                    </p>
                </div>
            </div>

            <!-- The 3D scene. Decorative: everything it shows is also said
                 in words on this page, so it is hidden from screen readers. -->
            <div class="dl-stage" aria-hidden="true">
                <div class="dl-scene" id="scene">
                    <div class="dl-ring"></div>

                    <div class="dl-phone is-back">
                        <div class="dl-phone-body"></div>
                        <div class="dl-phone-screen">
                            <img src="<?= asset('assets/screen-splash.webp') ?>" alt="" width="390" height="844" loading="lazy">
                        </div>
                    </div>

                    <div class="dl-phone is-front">
                        <div class="dl-phone-body"></div>
                        <div class="dl-phone-screen">
                            <img src="<?= asset('assets/screen-qr.webp') ?>" alt="" width="390" height="844">
                        </div>
                    </div>

                    <div class="dl-float-card">
                        <img src="<?= asset('assets/qr-card.webp') ?>" alt="" width="306" height="550">
                    </div>

                    <div class="dl-coin">
                        <div class="dl-coin-face"><img src="<?= htmlspecialchars($logo) ?>" alt=""></div>
                    </div>
                </div>
            </div>
        </section>

        <!-- ══ INSTALL ═══════════════════════════════════════════ -->
        <section class="dl-section" id="install">
            <div class="dl-section-head">
                <span class="dl-kicker">Install</span>
                <h2>Three steps, about a minute</h2>
                <p>The app is not on the Play Store, so Android asks a couple of extra questions the first time. That is expected.</p>
            </div>

            <ol class="dl-steps">
                <li class="dl-card dl-reveal">
                    <span class="dl-step-no">1</span>
                    <i class="bi bi-download dl-card-icon" aria-hidden="true"></i>
                    <h3>Download</h3>
                    <p>Tap <strong>Download for Android</strong>. If Chrome says the file might be harmful, tap <strong>Download anyway</strong>.</p>
                </li>
                <li class="dl-card dl-reveal">
                    <span class="dl-step-no">2</span>
                    <i class="bi bi-shield-check dl-card-icon" aria-hidden="true"></i>
                    <h3>Allow the install</h3>
                    <p>Open the file. Android asks to allow installs from Chrome — tap <strong>Settings</strong>, switch on <strong>Allow from this source</strong>, go back, and tap <strong>Install</strong>.</p>
                </li>
                <li class="dl-card dl-reveal">
                    <span class="dl-step-no">3</span>
                    <i class="bi bi-qr-code dl-card-icon" aria-hidden="true"></i>
                    <h3>Get your QR</h3>
                    <p>Open <strong><?= htmlspecialchars($acronym) ?></strong>, type your student number, accept the terms, and tap <strong>Generate</strong>. Save it — done.</p>
                </li>
            </ol>
        </section>

        <!-- ══ WHY ═══════════════════════════════════════════════ -->
        <section class="dl-section">
            <div class="dl-section-head">
                <span class="dl-kicker">Why the app</span>
                <h2>The same code, closer at hand</h2>
            </div>

            <div class="dl-features">
                <article class="dl-card dl-reveal">
                    <i class="bi bi-intersect dl-card-icon" aria-hidden="true"></i>
                    <h3>Identical to the web</h3>
                    <p>Built from the same rules on the same server, so the scanner reads it exactly like the one from the web page.</p>
                </article>
                <article class="dl-card dl-reveal">
                    <i class="bi bi-image dl-card-icon" aria-hidden="true"></i>
                    <h3>Saved to your phone</h3>
                    <p>Keep the card as an image or share it. A saved code shows at the door even without signal.</p>
                </article>
                <article class="dl-card dl-reveal">
                    <i class="bi bi-person-bounding-box dl-card-icon" aria-hidden="true"></i>
                    <h3>Photo reminder</h3>
                    <p>If your photo is missing, the app tells you right away — with a button to upload it — instead of the scanner telling you in class.</p>
                </article>
                <article class="dl-card dl-reveal">
                    <i class="bi bi-patch-check dl-card-icon" aria-hidden="true"></i>
                    <h3>Verified records only</h3>
                    <p>Only student numbers on the enrolment list get a code, so nobody can make one for a name that is not theirs.</p>
                </article>
            </div>
        </section>

        <!-- ══ FAQ ═══════════════════════════════════════════════ -->
        <section class="dl-section">
            <div class="dl-section-head">
                <span class="dl-kicker">Questions</span>
                <h2>Before you ask</h2>
            </div>

            <div class="dl-faq">
                <details class="dl-reveal">
                    <summary>Android warns the file might be harmful. Is it safe?</summary>
                    <p>
                        Android shows that warning for any app installed from outside the Play Store,
                        not because of anything in this one. Download it <strong>only from this page</strong>.
                        If Play Protect asks to scan it, let it; if it says the app is unknown, tap
                        <strong>More details → Install anyway</strong>.
                    </p>
                </details>
                <details class="dl-reveal">
                    <summary>I have an iPhone.</summary>
                    <p>
                        The app is Android only for now. The <a href="../QRgenerator/QRcode.php">web generator</a>
                        makes the very same QR code — open it in Safari and save the image.
                    </p>
                </details>
                <details class="dl-reveal">
                    <summary>Do I need internet?</summary>
                    <p>
                        To look up your record and generate the code, yes. Once it is saved, the image
                        works anywhere — you do not need signal to show it.
                    </p>
                </details>
                <details class="dl-reveal">
                    <summary>How do I update the app?</summary>
                    <p>
                        Download it again from this page and install it over the old one.
                        There is nothing to set up again.
                    </p>
                </details>
                <details class="dl-reveal">
                    <summary>The download does nothing, or opens a blank page.</summary>
                    <p>
                        You are probably inside Messenger or Facebook. Open this page in
                        <strong>Chrome</strong> instead — tap the <strong>⋮</strong> menu and choose
                        <strong>Open in browser</strong>.
                    </p>
                </details>
            </div>
        </section>

    </main>

    <?php include __DIR__ . '/../components/footer.php'; ?>
    <?php include __DIR__ . '/../includes/theme_toggle.php'; ?>

    <script src="https://cdn.jsdelivr.net/npm/qrcodejs/qrcode.min.js"></script>
    <script src="<?= asset('assets/download.js') ?>"></script>
    <script src="<?= asset('../assets/js/detection.js') ?>"></script>
</body>

</html>
