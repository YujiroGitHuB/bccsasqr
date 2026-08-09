<?php
// Include database connection
include "../includes/db_connect.php";
include __DIR__ . '/crud/att_display.php';
// Fetch lock setting from database
$query = mysqli_query($conn, "SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked'");
$row = mysqli_fetch_assoc($query);
$locked = ($row['setting_value'] === 'true'); // convert to boolean

if ($locked) {
    include __DIR__ . "/../includes/lock.php";
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Student Attendance Tracker</title>
    <link rel="shortcut icon" href="../assets/images/bcc logo.png" type="image/x-icon">
    <link rel="stylesheet" href="css/style.css">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
</head>

<body>
      <div id="particles-js"></div>
    <div class="container">
        <div class="card">
            <div class="header">
                <img
                    alt="QR Animation"
                    width="50"
                    height="50"
                    style="border-radius: 50%; object-fit: cover;"
                    src="https://cdn-icons-gif.flaticon.com/16075/16075899.gif" alt="">
                <h1>Student Attendance Tracker</h1>
                <h3>Track your attendance records</h3>
            </div>

            <div class="search-section">
                <div class="search-form">
                    <!-- Message box above input -->
                    <div id="messageContainer" class="message-container"></div>

                    <div class="search-wrapper">
                        <input
                            type="text"
                            id="studentNoInput"
                            class="search-input"
                            placeholder="Enter Student Number (e.g., 019-464)"
                            autocomplete="off">
                        <div class="search-status">
                            <span class="status-idle">Type to search...</span>
                            <span class="status-checking">
                                <svg class="spinner" viewBox="0 0 24 24">
                                    <circle class="spinner-circle" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" fill="none"></circle>
                                </svg>
                                Checking...
                            </span>
                        </div>
                    </div>
                </div>

                <div id="resultsContainer" class="results-container hidden"></div>
            </div>
            <!-- footer -->
            <?php include __DIR__ . "/../components/footer.php"; ?>
        </div>
    </div>
    <!-- TTS Manager -->
    <script src="../assets/js/tts.js"></script>
    <!-- retrieve -->
    <script src="js/script.js"></script>
    <!-- detection -->
    <script src="../assets/js/detection.js"></script>
      <!-- LOAD LIBRARIES FIRST -->
  <script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/stats.js/r17/Stats.min.js"></script>

  <!-- THEN YOUR SCRIPT -->
  <script src="../assets/js/shape.js"></script>

</body>

</html>