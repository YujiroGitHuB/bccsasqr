<?php require_once __DIR__ . '/includes/asset.php';

session_start();
include __DIR__ . '/includes/db_connect.php';
include __DIR__ . '/includes/systemConfig.php';

/* The host runs on UTC, so an unqualified date() here rendered the previous
   day's date in the plate footer for the whole 00:00-08:00 window in Manila.
   Every other file that prints a date sets this the same way. */
date_default_timezone_set('Asia/Manila');

/* The descriptive line above the wordmark comes from Settings, so
   renaming the system renames it here too. 'None' is what
   systemConfig.php falls back to on an empty column, and a heading
   reading "None" is worse than the real default.

   The wordmark itself is NOT taken from system_acronym. That column
   holds a versioned label ("BCC SASQR v1.0") — correct for a title
   bar, wrong at 3rem as the brand mark, and it would put a release
   number in the largest type on the page. */
$plateName = trim($systemName);
if ($plateName === '' || $plateName === 'None') {
    $plateName = 'Student Attendance System';
}

/* An uploaded logo can be deleted from disk while the row still
   points at it; the seal is the first thing on the page, so it falls
   back rather than rendering a broken image. */
$plateLogo = trim((string) $systemLogo);
if ($plateLogo === '' || !file_exists(__DIR__ . '/' . $plateLogo)) {
    $plateLogo = 'assets/images/bcc-logo.png';
}

/* index.php is the one includer of theme_head.php / theme_toggle.php
   that sits AT the project root, so it passes an empty prefix. */
$themeBase = '';
?>
<!doctype html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
    <meta name="theme-color" content="#0f172a">
    <title>BCC SASQR | Login</title>
    <link rel="icon" type="image/png" href="assets/images/bcc-logo.png">

    <!-- Tokens first: everything below reads from them. -->
    <?php include __DIR__ . '/includes/theme_head.php'; ?>

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

    <!-- Face-api.js for face recognition -->
    <script defer src="https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js"></script>

    <!-- Last, so it outranks Bootstrap where the two disagree. -->
    <link rel="stylesheet" href="<?= asset('assets/css/login.css') ?>">
</head>

<body class="login-page">
    <div id="particles-js"></div>

    <!-- Alert -->
    <?php include __DIR__ . "/includes/alert.php"; ?>

    <main class="login-shell">

        <!-- ── Left: brand plate ───────────────────────────────
             Deep slate in both themes: it is the brand ground, not
             a surface. See assets/css/login.css. -->
        <section class="login-plate">
            <div class="plate-modules" aria-hidden="true"><canvas id="plateModules"></canvas></div>
            <div class="plate-scan" aria-hidden="true"></div>

            <div class="plate-crest">
                <img src="<?= htmlspecialchars($plateLogo) ?>" alt="Binalatongan Community College seal"
                    class="logo-img" width="72" height="72">
                <div>
                    <h1>Binalatongan Community College</h1>
                    <p>San Carlos City, Pangasinan</p>
                </div>
            </div>

            <div class="plate-pitch">
                <span class="plate-eyebrow"><?= htmlspecialchars($plateName) ?></span>
                <!-- Only "QR" is tinted: the two letters that name what
                     the system actually does. -->
                <p class="plate-wordmark">SAS<span>QR</span></p>
                <p class="plate-lede">Scan a student ID, or let the camera do it. Attendance lands in the register the moment it is taken.</p>
            </div>

            <ul class="plate-caps">
                <li><i class="bi bi-qr-code-scan" aria-hidden="true"></i> QR ID scanning at the door</li>
                <li><i class="bi bi-person-bounding-box" aria-hidden="true"></i> Face recognition sign-in</li>
                <li><i class="bi bi-graph-up-arrow" aria-hidden="true"></i> Live registers and exports</li>
            </ul>

            <div class="plate-foot">
                <span class="plate-status"><i aria-hidden="true"></i> System online</span>
                <span><?= date('d M Y') ?></span>
            </div>
        </section>

        <!-- ── Right: the form ─────────────────────────────── -->
        <section class="login-panel">

            <div class="login-head">
                <h2>Sign in</h2>
                <p>Sign in to open the attendance dashboard.</p>
            </div>

            <!-- The two tabs are not equals: "Password" selects the
                 panel below, "Face login" opens the recognition modal
                 and leaves this one selected (assets/js/faceModal.js).
                 data-method and the .active class are read there. -->
            <div class="login-tabs">
                <button type="button" class="login-tab active" data-method="password">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
                        <path d="M8 1a2 2 0 0 1 2 2v4H6V3a2 2 0 0 1 2-2m3 6V3a3 3 0 0 0-6 0v4a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2" />
                    </svg>
                    Password
                </button>
                <button type="button" class="login-tab" data-method="face" id="faceLoginTab">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
                        <path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16" />
                        <path d="M4.285 9.567a.5.5 0 0 1 .683.183A3.5 3.5 0 0 0 8 11.5a3.5 3.5 0 0 0 3.032-1.75.5.5 0 1 1 .866.5A4.5 4.5 0 0 1 8 12.5a4.5 4.5 0 0 1-3.898-2.25.5.5 0 0 1 .183-.683M7 6.5C7 7.328 6.552 8 6 8s-1-.672-1-1.5S5.448 5 6 5s1 .672 1 1.5m4 0c0 .828-.448 1.5-1 1.5s-1-.672-1-1.5S9.448 5 10 5s1 .672 1 1.5" />
                    </svg>
                    Face login
                </button>
            </div>

            <!-- Password Login Method -->
            <div class="login-method active" id="passwordLogin">
                <form class="form" method="POST" action="crud/login_process.php">

                    <div class="input-container">
                        <label for="email">Email address</label>
                        <div class="input-field">
                            <i class="bi bi-envelope field-icon" aria-hidden="true"></i>
                            <input id="email" type="email" class="input-mail" name="email"
                                placeholder="name@example.com"
                                inputmode="email" autocomplete="username" autocapitalize="off"
                                autocorrect="off" spellcheck="false" required />
                        </div>
                    </div>

                    <div class="input-container password-container">
                        <label for="password">Password</label>
                        <div class="input-field">
                            <i class="bi bi-shield-lock field-icon" aria-hidden="true"></i>
                            <input id="password" type="password" class="input-pwd" name="password"
                                placeholder="Enter your password"
                                autocomplete="current-password" autocapitalize="off"
                                autocorrect="off" spellcheck="false" required />
                            <button type="button" class="password-toggle" onclick="togglePassword()"
                                aria-label="Show password" aria-controls="password">
                                <i class="bi bi-eye" id="toggleIcon"></i>
                            </button>
                        </div>
                    </div>

                    <button class="submit" type="submit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="17" height="17" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
                            <path d="M6 3.5a.5.5 0 0 1 .5-.5h8a.5.5 0 0 1 .5.5v9a.5.5 0 0 1-.5.5h-8a.5.5 0 0 1-.5-.5v-2a.5.5 0 0 0-1 0v2A1.5 1.5 0 0 0 6.5 14h8a1.5 1.5 0 0 0 1.5-1.5v-9A1.5 1.5 0 0 0 14.5 2h-8A1.5 1.5 0 0 0 5 3.5v2a.5.5 0 0 0 1 0z" />
                            <path d="M11.854 8.354a.5.5 0 0 0 0-.708l-3-3a.5.5 0 1 0-.708.708L10.293 7.5H1.5a.5.5 0 0 0 0 1h8.793l-2.147 2.146a.5.5 0 0 0 .708.708z" />
                        </svg>
                        <span class="sign-text">Sign in</span>
                    </button>
                </form>
            </div>

            <!-- Footer. components/footer.php renders an empty <footer>
                 when both settings columns are blank, which is the case
                 on this database — without the guard the panel ends in
                 a rule drawn above nothing. -->
            <?php if ($footerOrg !== '' || $footerDeveloper !== ''): ?>
                <div class="login-foot">
                    <?php include __DIR__ . "/components/footer.php"; ?>
                </div>
            <?php endif; ?>
        </section>
    </main>

    <!-- Face Login Modal -->
    <div class="face-login-modal" id="faceLoginModal">
        <div class="modal-content-face">
            <div class="modal-header-face">
                <h3>
                    <i class="bi bi-person-bounding-box"></i> Face recognition login
                </h3>
                <button class="close-modal" id="closeModalBtn" aria-label="Close">
                    <i class="bi bi-x"></i>
                </button>
            </div>

            <div class="face-video-wrapper-modal" id="faceVideoWrapper">
                <video id="loginFaceVideo" autoplay muted playsinline></video>
                <canvas id="loginFaceCanvas"></canvas>
            </div>

            <div class="face-login-status-modal" id="faceLoginStatus">
                Initializing face recognition...
            </div>

            <!-- Flashlight Toggle Button — shown by flashlight.js only
                 when the camera track actually supports a torch. -->
            <button class="flashlight-toggle" id="flashlightBtn" style="display: none;">
                <i class="bi bi-lightbulb" id="flashlightIcon"></i>
                <span id="flashlightText">Turn On Flash</span>
            </button>
        </div>
    </div>

    <!-- Floating light/dark switch (there is no topbar on this page) -->
    <?php include __DIR__ . '/includes/theme_toggle.php'; ?>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- LOAD LIBRARIES FIRST -->
    <script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"></script>

    <!-- THEN YOUR SCRIPT -->
    <script src="<?= asset('assets/js/shape.js') ?>"></script>
    <!-- QR module texture on the brand plate -->
    <script src="<?= asset('assets/js/loginPlate.js') ?>"></script>
    <!-- Show/hide password -->
    <script src="<?= asset('assets/js/showPassword.js') ?>"></script>

    <!-- Face login -->
    <script src="<?= asset('assets/js/faceLogin.js') ?>"></script>
    <!-- face modal -->
    <script src="<?= asset('assets/js/faceModal.js') ?>"></script>
    <!-- flashlight -->
    <script src="<?= asset('assets/js/flashlight.js') ?>"></script>

</body>

</html>
