<?php
session_start();
include __DIR__ . '/includes/db_connect.php';

// Fetch lock setting from database
$query = mysqli_query($conn, "SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked'");
$row = mysqli_fetch_assoc($query);
$locked = ($row['setting_value'] === 'true'); // convert to boolean

if ($locked) {
    include __DIR__ . "/includes/lock.php";
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>BCC SAS QR | Create Account</title>
    <link rel="icon" type="image/png" href="assets/images/bcc logo.png">

    <!-- External Libraries -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

    <!-- Face-api.js for face recognition -->
    <script defer src="https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js"></script>

    <!-- Custom Styles -->
    <link rel="stylesheet" href="assets/css/reg.css">

    <style>

    </style>
</head>

<body>
    <!-- ========================================
         ALERT SYSTEM
    ========================================= -->
    <?php include __DIR__ . "/includes/regAlert.php"; ?>

    <!-- ========================================
         MAIN CONTAINER
    ========================================= -->
    <div class="container">
        <img src="assets/images/bcc logo.png" alt="BCC Logo" class="logo-img">
        <h5>Binalatongan Community College</h5>
        <p>San Carlos City Pangasinan</p>
        <!-- PAGE TITLE -->
        <h2>Create Account</h2>

        <!-- ========================================
     REGISTRATION FORM
========================================= -->
        <form action="crud/reg_process.php" method="POST" id="registerForm">

            <!-- TWO COLUMN LAYOUT -->
            <div class="form-layout">

                <!-- LEFT PANEL: Form Fields -->
                <div class="left-panel">

                    <!-- FULL NAME INPUT -->
                    <div class="input-group">
                        <input type="text" id="name" name="name" required />
                        <label for="name">Full Name</label>
                    </div>

                    <!-- EMAIL INPUT -->
                    <div class="input-group">
                        <input type="email" id="email" name="email" required />
                        <label for="email">Email Address</label>
                    </div>

                    <!-- PASSWORD INPUT WITH TOGGLE -->
                    <div class="input-group">
                        <input type="password" id="password" name="password" minlength="6" required />
                        <label for="password">Password</label>

                        <button type="button" class="toggle-password" id="togglePassword">
                            <svg class="eye-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path class="eye-open" d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                                <circle class="eye-open" cx="12" cy="12" r="3"></circle>
                                <path class="eye-closed" style="display: none;" d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
                                <line class="eye-closed" style="display: none;" x1="1" y1="1" x2="23" y2="23"></line>
                            </svg>
                        </button>
                    </div>

                    <!-- PASSWORD STRENGTH INDICATOR -->
                    <div class="password-strength">
                        <span class="password-strength-text"></span>
                    </div>

                    <!-- PASSWORD REQUIREMENTS CHECKLIST -->
                    <div class="password-requirements">
                        <div class="requirement" id="req-length">
                            <span class="req-icon"></span>
                            <span class="req-text">At least 6 characters</span>
                        </div>
                        <div class="requirement" id="req-length-strong">
                            <span class="req-icon"></span>
                            <span class="req-text">At least 10 characters</span>
                        </div>
                        <div class="requirement" id="req-case">
                            <span class="req-icon"></span>
                            <span class="req-text">Uppercase & lowercase</span>
                        </div>
                        <div class="requirement" id="req-number">
                            <span class="req-icon"></span>
                            <span class="req-text">Contains number</span>
                        </div>
                        <div class="requirement" id="req-special">
                            <span class="req-icon"></span>
                            <span class="req-text">Contains special character</span>
                        </div>
                    </div>

                    <!-- CONFIRM PASSWORD INPUT WITH TOGGLE -->
                    <div class="input-group">
                        <input type="password" id="confirmPassword" required />
                        <label for="confirmPassword">Confirm Password</label>

                        <button type="button" class="toggle-password" id="toggleConfirmPassword">
                            <svg class="eye-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path class="eye-open" d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                                <circle class="eye-open" cx="12" cy="12" r="3"></circle>
                                <path class="eye-closed" style="display: none;" d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
                                <line class="eye-closed" style="display: none;" x1="1" y1="1" x2="23" y2="23"></line>
                            </svg>
                        </button>
                    </div>

                </div>
                <!-- END LEFT PANEL -->

                <!-- RIGHT PANEL: Face Recognition -->
                <div class="right-panel">
                    <div class="panel-header">
                        <h3><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-person-lock" viewBox="0 0 16 16">
                                <path d="M11 5a3 3 0 1 1-6 0 3 3 0 0 1 6 0M8 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4m0 5.996V14H3s-1 0-1-1 1-4 6-4q.845.002 1.544.107a4.5 4.5 0 0 0-.803.918A11 11 0 0 0 8 10c-2.29 0-3.516.68-4.168 1.332-.678.678-.83 1.418-.832 1.664zM9 13a1 1 0 0 1 1-1v-1a2 2 0 1 1 4 0v1a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1zm3-3a1 1 0 0 0-1 1v1h2v-1a1 1 0 0 0-1-1" />
                            </svg> Face Recognition</h3>
                        <p>Security feature</p>
                    </div>

                    <div class="face-preview" id="facePreview">
                        <div class="face-icon" id="faceIcon">
                            <svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" fill="currentColor" class="bi bi-person-bounding-box" viewBox="0 0 16 16">
                                <path d="M1.5 1a.5.5 0 0 0-.5.5v3a.5.5 0 0 1-1 0v-3A1.5 1.5 0 0 1 1.5 0h3a.5.5 0 0 1 0 1zM11 .5a.5.5 0 0 1 .5-.5h3A1.5 1.5 0 0 1 16 1.5v3a.5.5 0 0 1-1 0v-3a.5.5 0 0 0-.5-.5h-3a.5.5 0 0 1-.5-.5M.5 11a.5.5 0 0 1 .5.5v3a.5.5 0 0 0 .5.5h3a.5.5 0 0 1 0 1h-3A1.5 1.5 0 0 1 0 14.5v-3a.5.5 0 0 1 .5-.5m15 0a.5.5 0 0 1 .5.5v3a1.5 1.5 0 0 1-1.5 1.5h-3a.5.5 0 0 1 0-1h3a.5.5 0 0 0 .5-.5v-3a.5.5 0 0 1 .5-.5" />
                                <path d="M3 14s-1 0-1-1 1-4 6-4 6 3 6 4-1 1-1 1zm8-9a3 3 0 1 1-6 0 3 3 0 0 1 6 0" />
                            </svg>
                        </div>
                        <canvas id="facePreviewCanvas" style="display: none;"></canvas>
                        <p class="face-desc" id="faceDesc">Add face recognition for quick and secure login</p>
                    </div>

                    <div class="face-toggle-container">
                        <label class="face-toggle-label">
                            <span>Enable Face Recognition</span>
                            <div class="toggle-switch">
                                <input type="checkbox" id="enableFaceRecognition" name="enableFaceRecognition">
                                <span class="toggle-slider"></span>
                            </div>
                        </label>
                    </div>

                    <!-- ========================================
     FACE RECOGNITION MODAL
========================================= -->
                    <div id="faceModal" class="face-modal">
                        <div class="face-modal-content">
                            <button type="button" class="close-modal" id="closeModal">×</button>

                            <div class="face-section-header">
                                <h3>
                                    <svg xmlns="http://www.w3.org/2000/svg" width="90" height="90" fill="currentColor" class="bi bi-camera-fill" viewBox="0 0 16 16">
                                        <path d="M10.5 8.5a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0" />
                                        <path d="M2 4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-1.172a2 2 0 0 1-1.414-.586l-.828-.828A2 2 0 0 0 9.172 2H6.828a2 2 0 0 0-1.414.586l-.828.828A2 2 0 0 1 3.172 4zm.5 2a.5.5 0 1 1 0-1 .5.5 0 0 1 0 1m9 2.5a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0" />
                                    </svg>
                                </h3>
                                <p>Position your face in the camera frame</p>
                            </div>

                            <div class="video-container">
                                <video id="faceVideo" autoplay muted playsinline></video>
                                <canvas id="faceCanvas"></canvas>
                            </div>

                            <div id="faceStatus" class="face-status">
                                Initializing camera...
                            </div>

                            <button type="button" id="captureFaceBtn" class="btn" disabled>
                                Capture Your Face
                            </button>
                        </div>
                    </div>

                    <div class="face-status-box" id="faceStatusBox">
                        <p class="status-text">Face recognition disabled</p>
                    </div>

                </div>
                <!-- END RIGHT PANEL -->

            </div>
            <!-- END TWO COLUMN LAYOUT -->

            <!-- Hidden field to store face descriptor -->
            <input type="hidden" id="faceDescriptor" name="faceDescriptor">

            <!-- ERROR/SUCCESS MESSAGE DISPLAY -->
            <div class="message" id="message"></div>

            <!-- SUBMIT BUTTON -->
            <button type="submit" class="btn">Register</button>

        </form>

        <!-- ========================================
             FOOTER
        ========================================= -->
        <footer>
            &copy; 2025 Binalatongan Community College. All rights reserved. |
            Developed by
            <a href="https://cncc.vercel.app/" target="_blank">
                Charles Nixon C. Cayading
            </a>
        </footer>

    </div>
    <!-- END MAIN CONTAINER -->

    <!-- ========================================
         JAVASCRIPT FILES
    ========================================= -->

    <!-- Text-to-Speech -->
    <script src="assets/js/tts.js"></script>

    <!-- Form Validation & Interaction -->
    <script src="assets/js/regScript.js"></script>

    <!-- Face Recognition Script -->
    <script src="assets/js/faceRecognition.js"></script>

</body>

</html>