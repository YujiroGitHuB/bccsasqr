<?php
session_start();
include __DIR__ . '/includes/db_connect.php';
?>
<!doctype html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=360, height=800, initial-scale=1.0">
    <title>BCC SAS QR | Login</title>
    <link rel="icon" type="image/png" href="assets/images/bcc logo.png">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

    <!-- Face-api.js for face recognition -->
    <script defer src="https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js"></script>

    <link rel="stylesheet" href="assets/css/login.css?v=1.1">
</head>

<body>
    <div id="particles-js"></div>
    <!-- Alert -->
    <?php include __DIR__ . "/includes/alert.php"; ?>

    <div class="login-card text-center">
        <img src="assets/images/bcc logo.png" alt="BCC Logo" class="logo-img">
        <h5>Binalatongan Community College</h5>
        <p>San Carlos City Pangasinan</p>

        <!-- Login Method Tabs -->
        <div class="login-tabs">
            <div class="login-tab active" data-method="password">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-shield-lock" viewBox="0 0 16 16">
                    <path d="M5.338 1.59a61 61 0 0 0-2.837.856.48.48 0 0 0-.328.39c-.554 4.157.726 7.19 2.253 9.188a10.7 10.7 0 0 0 2.287 2.233c.346.244.652.42.893.533q.18.085.293.118a1 1 0 0 0 .101.025 1 1 0 0 0 .1-.025q.114-.034.294-.118c.24-.113.547-.29.893-.533a10.7 10.7 0 0 0 2.287-2.233c1.527-1.997 2.807-5.031 2.253-9.188a.48.48 0 0 0-.328-.39c-.651-.213-1.75-.56-2.837-.855C9.552 1.29 8.531 1.067 8 1.067c-.53 0-1.552.223-2.662.524zM5.072.56C6.157.265 7.31 0 8 0s1.843.265 2.928.56c1.11.3 2.229.655 2.887.87a1.54 1.54 0 0 1 1.044 1.262c.596 4.477-.787 7.795-2.465 9.99a11.8 11.8 0 0 1-2.517 2.453 7 7 0 0 1-1.048.625c-.28.132-.581.24-.829.24s-.548-.108-.829-.24a7 7 0 0 1-1.048-.625 11.8 11.8 0 0 1-2.517-2.453C1.928 10.487.545 7.169 1.141 2.692A1.54 1.54 0 0 1 2.185 1.43 63 63 0 0 1 5.072.56" />
                    <path d="M9.5 6.5a1.5 1.5 0 0 1-1 1.415l.385 1.99a.5.5 0 0 1-.491.595h-.788a.5.5 0 0 1-.49-.595l.384-1.99a1.5 1.5 0 1 1 2-1.415" />
                </svg>
                Password
            </div>
            <div class="login-tab" data-method="face" id="faceLoginTab">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-person-fill-lock" viewBox="0 0 16 16">
                    <path d="M11 5a3 3 0 1 1-6 0 3 3 0 0 1 6 0m-9 8c0 1 1 1 1 1h5v-1a2 2 0 0 1 .01-.2 4.49 4.49 0 0 1 1.534-3.693Q8.844 9.002 8 9c-5 0-6 3-6 4m7 0a1 1 0 0 1 1-1v-1a2 2 0 1 1 4 0v1a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1zm3-3a1 1 0 0 0-1 1v1h2v-1a1 1 0 0 0-1-1" />
                </svg> Face Login
            </div>
        </div>

        <!-- Password Login Method -->
        <div class="login-method active" id="passwordLogin">
            <form class="form" method="POST" action="crud/login_process.php">
                <div class="form-title"><span>sign in to your</span></div>
                <div class="title-2"><span>SASQR</span></div>

                <div class="input-container">
                    <label for="email">Email Address</label>
                    <input id="email" type="email" class="input-mail" name="email" />
                </div>

                <div class="input-container password-container">
                    <label for="password">Password</label>
                    <input id="password" type="password" class="input-pwd" name="password" />
                    <button type="button" class="password-toggle" onclick="togglePassword()">
                        <i class="bi bi-eye" id="toggleIcon"></i>
                    </button>
                </div>

                <section class="bg-stars">
                    <span class="star"></span>
                    <span class="star"></span>
                    <span class="star"></span>
                    <span class="star"></span>
                </section>

                <button class="submit" type="submit">
                    <span class="sign-text">Sign in</span>
                </button>
            </form>
        </div>

        <!-- Footer -->
        <?php include __DIR__ . "/components/footer.php"; ?>
    </div>

    <!-- Face Login Modal -->
    <div class="face-login-modal" id="faceLoginModal">
        <div class="modal-content-face">
            <div class="modal-header-face">
                <h3>
                    <i class="bi bi-person-fill-lock"></i> Face Recognition Login
                </h3>
                <button class="close-modal" id="closeModalBtn">
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

            <!-- Flashlight Toggle Button -->
            <button class="flashlight-toggle" id="flashlightBtn" style="display: none;">
                <i class="bi bi-lightbulb" id="flashlightIcon"></i>
                <span id="flashlightText">Turn On Flash</span>
            </button>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- LOAD LIBRARIES FIRST -->
    <script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/stats.js/r17/Stats.min.js"></script>

    <!-- THEN YOUR SCRIPT -->
    <script src="assets/js/shape.js"></script>
    <!-- Show/hide password -->
    <script src="assets/js/showPassword.js"></script>

    <!-- Face login -->
    <script src="assets/js/faceLogin.js"></script>
    <!-- face modal -->
    <script src="assets/js/faceModal.js"></script>
    <!-- flashlight -->
    <script src="assets/js/flashlight.js"></script>

</body>

</html>