<?php require_once __DIR__ . '/../includes/asset.php';

include "../includes/db_connect.php"; // ensure this connects to your DB

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

<body>
  <div id="particles-js"></div>
  <div class="container">
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
  <script src="<?= asset('js/instruction.js') ?>"></script>
  <script src="<?= asset('../assets/js/detection.js') ?>"></script>

  <!-- LOAD LIBRARIES FIRST -->
  <script src="https://cdn.jsdelivr.net/npm/particles.js@2.0.0/particles.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/stats.js/r17/Stats.min.js"></script>

  <!-- THEN YOUR SCRIPT -->
  <script src="<?= asset('../assets/js/shape.js') ?>"></script>
  <!-- assistant -->
  <script src="<?= asset('../assets/js/widget.js') ?>"></script>

</body>

</html>