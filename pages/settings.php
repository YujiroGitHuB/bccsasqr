<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if (!isAdmin()) {
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

// Handle Page Lock Toggle
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lock_status'])) {
    $newStatus = $_POST['lock_status'];
    $stmt = $conn->prepare("UPDATE lock_settings_tbl SET setting_value = ? WHERE setting_key = 'page_locked'");
    $stmt->bind_param("s", $newStatus);
    $update = $stmt->execute();

    if ($update) {
        echo json_encode(['success' => true, 'status' => $newStatus]);
    } else {
        echo json_encode(['success' => false, 'error' => $stmt->error]);
    }
    exit;
}

// Handle Attendance Lock Toggle
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['attendance_lock_status'])) {
    $newStatus = $_POST['attendance_lock_status'];

    // Check if setting exists
    $check = mysqli_query($conn, "SELECT * FROM attendance_settings WHERE setting_key = 'form_locked'");

    if (mysqli_num_rows($check) > 0) {
        $stmt = $conn->prepare("UPDATE attendance_settings SET setting_value = ?, updated_at = NOW() WHERE setting_key = 'form_locked'");
        $stmt->bind_param("s", $newStatus);
    } else {
        $stmt = $conn->prepare("INSERT INTO attendance_settings (setting_key, setting_value, updated_at) VALUES ('form_locked', ?, NOW())");
        $stmt->bind_param("s", $newStatus);
    }
    $update = $stmt->execute();

    if ($update) {
        echo json_encode(['success' => true, 'status' => $newStatus]);
    } else {
        echo json_encode(['success' => false, 'error' => $stmt->error]);
    }
    exit;
}

// Get current page lock status
$result = mysqli_query($conn, "SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked'");
$current = mysqli_fetch_assoc($result)['setting_value'];
$isLocked = ($current === 'true');

// Get attendance lock status
$attendanceResult = mysqli_query($conn, "SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");
$attendanceLocked = 0;
if ($attendanceResult && mysqli_num_rows($attendanceResult) > 0) {
    $attendanceData = mysqli_fetch_assoc($attendanceResult);
    $attendanceLocked = (int)$attendanceData['setting_value'];
}
$isAttendanceLocked = ($attendanceLocked === 1);

// Get current system configuration
$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);
$systemName = $system['system_name'] ?? '';
$systemAcronym = $system['system_acronym'] ?? '';
$systemLogo = $system['logo'] ?? '';
?>

<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>
        <h2><i class="bi bi-sliders"></i> Manage Settings</h2>
        <div class="settings-container">
            <!-- Page Lock Settings -->
            <div class="settings-card">
                <h2><i class="bi bi-shield-lock-fill"></i> Page Lock Settings</h2>
                <p class="status-text"> Current Status: <?php if ($isLocked): ?> <span class="locked"><i class="bi bi-lock"></i> LOCKED</span> <?php else: ?> <span class="unlocked"><i class="bi bi-unlock-fill"></i> UNLOCKED</span> <?php endif; ?> </p>
                <form method="post" id="lockForm"> <input type="hidden" name="lock_status" id="lock_status" value="<?= $isLocked ? 'true' : 'false' ?>">
                    <div class="toggle-container">
                        <div class="toggle-wrap"> <input class="toggle-input" id="holo-toggle" type="checkbox" <?= $isLocked ? 'checked' : '' ?> /> <label class="toggle-track" for="holo-toggle">
                                <div class="track-lines">
                                    <div class="track-line"></div>
                                </div>
                                <div class="toggle-thumb">
                                    <div class="thumb-core"></div>
                                    <div class="thumb-inner"></div>
                                    <div class="thumb-scan"></div>
                                    <div class="thumb-particles">
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                    </div>
                                </div>

                                <div class="energy-rings">
                                    <div class="energy-ring"></div>
                                    <div class="energy-ring"></div>
                                    <div class="energy-ring"></div>
                                </div>
                                <div class="interface-lines">
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                </div>
                                <div class="toggle-reflection"></div>
                                <div class="holo-glow"></div>
                            </label>
                        </div>
                    </div>
                </form>
            </div>

            <!-- Attendance Lock Settings -->
            <div class="settings-card">
                <h2><i class="bi bi-calendar-check-fill"></i> Attendance Lock Settings</h2>
                <p class="status-text"> Current Status: <?php if ($isAttendanceLocked): ?> <span class="locked"><i class="bi bi-lock"></i> LOCKED</span> <?php else: ?> <span class="unlocked"><i class="bi bi-unlock-fill"></i> UNLOCKED</span> <?php endif; ?> </p>
                <form method="post" id="attendanceLockForm"> <input type="hidden" name="attendance_lock_status" id="attendance_lock_status" value="<?= $isAttendanceLocked ? '1' : '0' ?>">
                    <div class="toggle-container">
                        <div class="toggle-wrap"> <input class="toggle-input" id="attendance-toggle" type="checkbox" <?= $isAttendanceLocked ? 'checked' : '' ?> /> <label class="toggle-track" for="attendance-toggle">
                                <div class="track-lines">
                                    <div class="track-line"></div>
                                </div>
                                <div class="toggle-thumb">
                                    <div class="thumb-core"></div>
                                    <div class="thumb-inner"></div>
                                    <div class="thumb-scan"></div>
                                    <div class="thumb-particles">
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                        <div class="thumb-particle"></div>
                                    </div>
                                </div>

                                <div class="energy-rings">
                                    <div class="energy-ring"></div>
                                    <div class="energy-ring"></div>
                                    <div class="energy-ring"></div>
                                </div>
                                <div class="interface-lines">
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                    <div class="interface-line"></div>
                                </div>
                                <div class="toggle-reflection"></div>
                                <div class="holo-glow"></div>
                            </label>
                        </div>
                    </div>
                </form>
            </div>

            <!-- System Configuration -->
            <div class="settings-card">
                <h2><i class="bi bi-gear-fill"></i> System Configuration</h2>
                <button class="btn btn-success" data-bs-toggle="modal" data-bs-target="#systemConfigModal">
                    <i class="bi bi-arrow-repeat"></i> Update System
                </button>
            </div>

            <?php include __DIR__ . "/../components/systemConfig.php"; ?>

        </div>
    </div> <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="<?= asset('../assets/js/attendancelock.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>
    <script src="<?= asset('../assets/js/userManagement.js') ?>"></script>
</body>

</html>