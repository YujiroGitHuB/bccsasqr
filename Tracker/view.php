<?php require_once __DIR__ . '/../includes/asset.php';

// Include database connection
include "../includes/db_connect.php";
include __DIR__ . '/crud/att_display.php';

// The display board is often left running on a projector with nobody
// signed in, so anonymous access stays open — a signed-in instructor
// without the permission is sent back to their dashboard.
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
include __DIR__ . "/../includes/permissions.php";
requirePermissionIfSignedIn('qr.tracker');
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
    <?php include __DIR__ . "/../includes/headerTracker.php"; ?>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
</head>

<body class="trk-page">
    <div id="particles-js"></div>

    <div class="trk-shell">
        <!-- Hero — the same shape as the QR Generator and the admin
             pages (.stud-hero): a gradient rule on top, an icon tile,
             the title, and chips. The logo used to be a GIF from the
             flaticon CDN, and the subtitle was an <h3> following
             straight after the <h1> — a gap in the heading order. -->
        <header class="trk-hero">
            <div class="trk-hero-icon">
                <img src="../<?php echo $systemLogo; ?>" alt="" width="34" height="34">
            </div>

            <div class="trk-hero-text">
                <h1>Attendance Tracker</h1>
                <p>Check how many times you have been marked present in each subject.</p>
            </div>

            <div class="trk-chips">
                <span class="trk-chip"><i class="bi bi-eye"></i> View only</span>
                <span class="trk-chip"><i class="bi bi-clock-history"></i> Updated live</span>
            </div>
        </header>

        <section class="trk-panel">
            <h2 class="panel-title"><i class="bi bi-search"></i> Find your record</h2>

            <label class="field-label" for="studentNoInput">Student number</label>

            <div class="search-wrapper">
                <input
                    type="text"
                    id="studentNoInput"
                    class="search-input"
                    placeholder="019-464"
                    inputmode="numeric"
                    autocomplete="off">
                <!-- After the input so `:focus ~ .search-icon` works -->
                <i class="bi bi-hash search-icon"></i>
                <div class="search-status">
                    <span class="status-idle">Type to search</span>
                    <span class="status-checking">
                        <svg class="spinner" viewBox="0 0 24 24">
                            <circle class="spinner-circle" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" fill="none"></circle>
                        </svg>
                        <span>Checking</span>
                    </span>
                </div>
            </div>

            <span class="field-hint">The search runs on its own — no need to press anything.</span>

            <!-- The message sits below the input now. Above it, its
                 appearing pushed the field down while you were
                 typing. -->
            <div id="messageContainer" class="message-container"></div>
        </section>

        <!-- Waiting state: this part used to be blank until the first
             search. -->
        <div id="trkPlaceholder" class="trk-placeholder">
            <i class="bi bi-calendar2-check"></i>
            <h2>No record shown yet</h2>
            <p>Enter your student number above to see your attendance per subject.</p>
        </div>

        <div id="resultsContainer" class="results-container hidden"></div>

        <!-- footer -->
        <?php include __DIR__ . "/../components/footer.php"; ?>
    </div>

    <!-- TTS Manager -->
    <script src="<?= asset('../assets/js/tts.js') ?>"></script>
    <!-- retrieve -->
    <script src="<?= asset('js/script.js') ?>"></script>
    <!-- detection -->
    <script src="<?= asset('../assets/js/detection.js') ?>"></script>
    <!-- LOAD LIBRARIES FIRST -->
    <script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/stats.js/r17/Stats.min.js"></script>

    <!-- THEN YOUR SCRIPT -->
    <script src="<?= asset('../assets/js/shape.js') ?>"></script>

<?php include __DIR__ . "/../includes/theme_toggle.php"; ?>
</body>

</html>
