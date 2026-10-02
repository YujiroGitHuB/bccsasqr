<?php require_once __DIR__ . '/../includes/asset.php';

/* ============================================================
 * download/ — where students and instructors get the Android app.
 *
 * Public, like the QR generator: students do not log in. The app
 * holds both halves — the students' QR generator and attendance
 * tracker, and the instructors' scanner — so the page speaks to both.
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
require_once __DIR__ . '/../includes/app_release.php';

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

// Read from the APK itself, as the app's update check reads it, so a
// student sent here by "Update available" sees the version it named.
$apkVersion = $apkReady ? (app_release()['version'] ?? null) : null;

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
    <?php
    require_once __DIR__ . '/../includes/share_meta.php';
    share_meta([
        'title'       => 'Get the ' . $acronym . ' app',
        'description' => 'Download the ' . $acronym . ' Android app: students keep their attendance QR on their phone and check their attendance, instructors scan it.',
    ]);
    ?>
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
                <span class="dl-chip"><i class="bi bi-android2" aria-hidden="true"></i> Android app · Students &amp; Instructors</span>

                <h1>Your QR code, attendance and scanner, <span class="dl-grad">in one app.</span></h1>

                <p class="dl-lead">
                    Students save the same QR code the classroom scanner reads
                    and check their attendance. Instructors sign in and scan it — into the same Attendance
                    List as the web system.
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
                    <?php if ($apkVersion !== null): ?>
                        <li><i class="bi bi-tag" aria-hidden="true"></i> Version <?= htmlspecialchars($apkVersion) ?></li>
                    <?php endif; ?>
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

            <!-- The 3D scene: the app's three screens, one in front and the
                 other two behind it. Swipe, drag, the arrows or the pills
                 bring another to the front (assets/download.js). The phones
                 are decoration — everything they show is said in words on
                 this page — so only the controls reach a screen reader.
                 The positions are in the markup too, so without JavaScript
                 the three still stand arranged. The same demo student on
                 every screen, 000-1023: no year-000 number exists. -->
            <div class="dl-stage">
                <div class="dl-scene" id="scene" data-active="0" aria-hidden="true">
                    <div class="dl-ring"></div>

                    <div class="dl-phone is-active" data-screen="0">
                        <div class="dl-phone-body"></div>
                        <div class="dl-phone-screen">
                            <img src="<?= asset('assets/screen-qr.webp') ?>" alt="" width="390" height="844">
                        </div>
                    </div>

                    <div class="dl-phone is-next" data-screen="1">
                        <div class="dl-phone-body"></div>
                        <div class="dl-phone-screen">
                            <img src="<?= asset('assets/screen-tracker.webp') ?>" alt="" width="390" height="844" loading="lazy">
                        </div>
                    </div>

                    <div class="dl-phone is-prev" data-screen="2">
                        <div class="dl-phone-body"></div>
                        <div class="dl-phone-screen">
                            <img src="<?= asset('assets/screen-scanner.webp') ?>" alt="" width="390" height="844" loading="lazy">
                        </div>
                    </div>

                    <!-- The saved card, out in front of My QR Code only. -->
                    <div class="dl-float-card">
                        <img src="<?= asset('assets/qr-card.webp') ?>" alt="" width="306" height="550">
                    </div>

                    <div class="dl-coin">
                        <div class="dl-coin-face"><img src="<?= htmlspecialchars($logo) ?>" alt=""></div>
                    </div>
                </div>

                <div class="dl-switch" role="group" aria-label="Screens in the app">
                    <button type="button" class="dl-arrow" data-step="-1" aria-label="Previous screen">
                        <i class="bi bi-chevron-left" aria-hidden="true"></i>
                    </button>
                    <div class="dl-pills">
                        <button type="button" class="dl-pill" data-go="0" aria-pressed="true">
                            <i class="bi bi-qr-code" aria-hidden="true"></i> My QR Code
                        </button>
                        <button type="button" class="dl-pill" data-go="1" aria-pressed="false">
                            <i class="bi bi-calendar2-check" aria-hidden="true"></i> Attendance
                        </button>
                        <button type="button" class="dl-pill" data-go="2" aria-pressed="false">
                            <i class="bi bi-qr-code-scan" aria-hidden="true"></i> Scanner
                        </button>
                    </div>
                    <button type="button" class="dl-arrow" data-step="1" aria-label="Next screen">
                        <i class="bi bi-chevron-right" aria-hidden="true"></i>
                    </button>
                </div>
            </div>
        </section>

        <!-- ══ TWO SIDES ═════════════════════════════════════════ -->
        <!-- The app splits the same way: on its first launch it asks who is
             using the phone, and shows students their side only and
             instructors the scanner's bar (lib/views/role_picker_page.dart). -->
        <section class="dl-section" id="inside">
            <div class="dl-section-head">
                <span class="dl-kicker">Inside the app</span>
                <h2>One app, two sides</h2>
                <p>The first time it opens, the app asks who you are. Students see only their QR code and their attendance; instructors sign in and get the scanner.</p>
            </div>

            <div class="dl-sides">
                <article class="dl-card dl-side dl-reveal">
                    <div class="dl-side-head">
                        <i class="bi bi-qr-code dl-card-icon" aria-hidden="true"></i>
                        <div>
                            <span class="dl-side-for">For students</span>
                            <h3>My QR Code &amp; My Attendance</h3>
                        </div>
                    </div>
                    <ul class="dl-side-list">
                        <li><i class="bi bi-intersect" aria-hidden="true"></i><span><strong>The same code as the web page</strong> — built by the same rules on the same server, so the scanner reads both alike.</span></li>
                        <li><i class="bi bi-image" aria-hidden="true"></i><span><strong>Saved to your phone.</strong> Keep it as an image or share it; it shows at the door even without signal.</span></li>
                        <li><i class="bi bi-person-bounding-box" aria-hidden="true"></i><span><strong>Photo reminder.</strong> If your photo is missing you are told right away, with a button to upload it — not by the scanner in class.</span></li>
                        <li><i class="bi bi-calendar2-check" aria-hidden="true"></i><span><strong>Your attendance, per subject.</strong> Tap My Attendance to see every day you were marked present, with the time and any late mark.</span></li>
                        <li><i class="bi bi-patch-check" aria-hidden="true"></i><span><strong>Verified records only.</strong> Only student numbers on the enrolment list get a code.</span></li>
                    </ul>
                </article>

                <article class="dl-card dl-side dl-reveal">
                    <div class="dl-side-head">
                        <i class="bi bi-qr-code-scan dl-card-icon" aria-hidden="true"></i>
                        <div>
                            <span class="dl-side-for">For instructors</span>
                            <h3>Attendance Scanner</h3>
                        </div>
                    </div>
                    <ul class="dl-side-list">
                        <li><i class="bi bi-person-lock" aria-hidden="true"></i><span><strong>Your web system account.</strong> Sign in once with the same email and password; the phone keeps you signed in until you sign out, and can keep the scanner behind your fingerprint.</span></li>
                        <li><i class="bi bi-camera" aria-hidden="true"></i><span><strong>Pick a subject, then scan.</strong> Each scan shows the student’s photo, beeps, vibrates and reads the name aloud.</span></li>
                        <li><i class="bi bi-alarm" aria-hidden="true"></i><span><strong>Late marking and a flashlight</strong> are a tap away — for a class that has started, or a dim room.</span></li>
                        <li><i class="bi bi-list-check" aria-hidden="true"></i><span><strong>The same Attendance List.</strong> The app follows the web scanner’s rules, and both fill the same records.</span></li>
                        <li><i class="bi bi-window-dock" aria-hidden="true"></i><span><strong>Everything on one bar.</strong> The scanner, the QR generator and the attendance tracker sit side by side along the bottom, so you can look a student up without losing your subject.</span></li>
                    </ul>
                </article>
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
                    <i class="bi bi-box-arrow-in-right dl-card-icon" aria-hidden="true"></i>
                    <h3>Open your side</h3>
                    <p>Open <strong><?= htmlspecialchars($acronym) ?></strong> and pick <strong>I&rsquo;m a student</strong> or <strong>I&rsquo;m an instructor</strong>. Students: tap <strong>My QR Code</strong>, type your student number, accept the terms, and save your QR &mdash; or tap <strong>My Attendance</strong> to see your days present. Instructors: sign in once with your web system account &mdash; <strong>Home</strong> opens with today&rsquo;s scans, and <strong>Scan now</strong> starts the scanner.</p>
                </li>
            </ol>
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
                    <summary>I am an instructor. Can I scan with this app?</summary>
                    <p>
                        Yes. Open the app, choose <strong>I&rsquo;m an instructor</strong>, and sign in with the
                        same email and password you use on the web system. It records attendance by the
                        same rules as the web scanner, into the same Attendance List. Lost your phone?
                        Change your password in <strong>My Profile</strong> and every phone is signed out.
                    </p>
                </details>
                <details class="dl-reveal">
                    <summary>I have an iPhone.</summary>
                    <p>
                        The app is Android only for now. The <a href="../QRgenerator/QRcode.php">web generator</a>
                        makes the very same QR code — open it in Safari and save the image. Instructors can
                        sign in to the web system in Safari and use the <a href="../Qrscanner/qrscanner.php">web scanner</a>.
                    </p>
                </details>
                <details class="dl-reveal">
                    <summary>Do I need internet?</summary>
                    <p>
                        To look up your record and generate the code, yes. Once it is saved, the image
                        works anywhere — you do not need signal to show it. My Attendance and the scanner
                        need internet too: they read and save the records on the server.
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
