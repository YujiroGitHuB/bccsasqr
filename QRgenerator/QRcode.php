<?php require_once __DIR__ . '/../includes/asset.php';

include "../includes/db_connect.php"; // ensure this connects to your DB

// This page has never required a login (it is opened on shared
// machines to print codes), so anonymous visitors are left as they
// were — but a signed-in instructor still needs the permission.
if (session_status() === PHP_SESSION_NONE) {
  session_start();
}
include __DIR__ . "/../includes/permissions.php";
requirePermissionIfSignedIn('qr.generator');

// Fetch lock setting from database
$query = mysqli_query($conn, "SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked'");
$row = mysqli_fetch_assoc($query);
$locked = ($row['setting_value'] === 'true'); // convert to boolean

if ($locked) {
  include __DIR__ . "/../includes/lock.php";
  exit;
}
?>

<!doctype html>
<html lang="en">

<head>
  <?php include __DIR__ . "/../includes/systemConfig.php"; ?>
  <?php include __DIR__ . "/../includes/headerQrGenerator.php"; ?>
  <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
</head>

<body class="qr-page">
  <div id="particles-js"></div>

  <div class="qr-shell">
    <!-- Hero — the same shape as the admin pages (.stud-hero): a
         gradient rule on top, an icon tile, the title, and chips. The
         title used to be buried inside an <h2> with inline flex and a
         GIF from the flaticon CDN. -->
    <header class="qr-hero">
      <div class="qr-hero-icon">
        <img src="../<?php echo $systemLogo; ?>" alt="" width="34" height="34">
      </div>

      <div class="qr-hero-text">
        <h1><?php echo htmlspecialchars($systemAcronym); ?> Code Generator</h1>
        <p>Look up your record and generate the QR code used for attendance.</p>
      </div>

      <div class="qr-chips">
        <span class="qr-chip"><i class="bi bi-shield-lock"></i> Verified records only</span>
        <span class="qr-chip"><i class="bi bi-download"></i> Free download</span>
      </div>
    </header>

    <!-- left panel -->
    <?php include __DIR__ . "/components/left_panel.php" ?>
    <!-- right panel -->
    <?php include __DIR__ . "/components/right_panel.php" ?>
    <!-- footer -->
    <?php include __DIR__ . "/../components/footer.php"; ?>
  </div>

  <!-- assistant -->
  <?php include __DIR__ . "/components/assistant.php" ?>
  <!-- script -->
  <script src="https://cdn.jsdelivr.net/npm/qrcodejs/qrcode.min.js"></script>
  <!-- text to speech -->
  <script src="<?= asset('../assets/js/tts.js') ?>"></script>
  <script src="<?= asset('js/scriptv2.js') ?>"></script>
  <script src="<?= asset('js/fetch_students.js') ?>"></script>
  <!-- Must come after fetch_students.js — it wraps the Generate
       button's enable/disable -->
  <script src="<?= asset('js/terms.js') ?>"></script>
  <script src="<?= asset('js/instruction.js') ?>"></script>
  <script src="<?= asset('../assets/js/detection.js') ?>"></script>

  <!-- LOAD LIBRARIES FIRST -->
  <script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/stats.js/r17/Stats.min.js"></script>

  <!-- THEN YOUR SCRIPT -->
  <script src="<?= asset('../assets/js/shape.js') ?>"></script>
  <!-- assistant -->
  <script src="<?= asset('../assets/js/widget.js') ?>"></script>

<?php include __DIR__ . "/../includes/theme_toggle.php"; ?>
</body>

</html>
