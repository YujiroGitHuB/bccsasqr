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

// Handle Student Photo Requirement Toggle
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['require_photo_status'])) {
    $newStatus = $_POST['require_photo_status'] === '1' ? '1' : '0';

    // May UNIQUE KEY ang setting_key, kaya isang statement lang ang
    // kailangan — mag-i-insert kung wala pa, mag-a-update kung meron na.
    $stmt = $conn->prepare("
        INSERT INTO attendance_settings (setting_key, setting_value, updated_at)
        VALUES ('require_student_photo', ?, NOW())
        ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()
    ");
    $stmt->bind_param("s", $newStatus);

    if ($stmt->execute()) {
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

// Get student photo requirement status (naka-OFF ang default kapag
// wala pang row — tingnan ang migration para sa dahilan)
$photoReqResult = mysqli_query($conn, "SELECT setting_value FROM attendance_settings WHERE setting_key = 'require_student_photo'");
$isPhotoRequired = false;
if ($photoReqResult && mysqli_num_rows($photoReqResult) > 0) {
    $isPhotoRequired = (mysqli_fetch_assoc($photoReqResult)['setting_value'] === '1');
}

// Ilan ang maaapektuhan kapag binuksan ito — mahalagang makita ng
// admin bago pindutin, dahil hindi makakapag-attendance ang mga
// estudyanteng walang photo.
$photoStats = mysqli_query($conn, "
    SELECT COUNT(*) AS total,
           SUM(CASE WHEN p.photo_path IS NULL OR p.photo_path = '' THEN 1 ELSE 0 END) AS missing
    FROM students_tbl s
    LEFT JOIN student_photos p ON p.s_id = s.id
");
$photoTotal   = 0;
$photoMissing = 0;
if ($photoStats && mysqli_num_rows($photoStats) > 0) {
    $row          = mysqli_fetch_assoc($photoStats);
    $photoTotal   = (int)$row['total'];
    $photoMissing = (int)$row['missing'];
}

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

            <!-- Student Photo Requirement -->
            <div class="settings-card">
                <h2><i class="bi bi-person-badge-fill"></i> Student Photo Requirement</h2>
                <p class="status-text">
                    Current Status:
                    <?php if ($isPhotoRequired): ?>
                        <span class="locked"><i class="bi bi-shield-lock-fill"></i> REQUIRED</span>
                    <?php else: ?>
                        <span class="unlocked"><i class="bi bi-shield-slash"></i> OPTIONAL</span>
                    <?php endif; ?>
                </p>

                <p style="font-size:.85rem; color:#94a3b8; max-width:520px; margin:0 auto 1rem;">
                    When ON, students without an uploaded photo cannot record attendance —
                    the instructor has no face to check against the QR being presented.
                    When OFF, the scan still goes through but shows a warning that
                    identity could not be verified.
                </p>

                <?php if ($photoMissing > 0): ?>
                    <p style="font-size:.82rem; color:<?= $isPhotoRequired ? '#f87171' : '#facc15' ?>;
                              background:rgba(250,204,21,.08); border:1px solid rgba(250,204,21,.25);
                              border-radius:8px; padding:.6rem .9rem; max-width:520px; margin:0 auto 1rem;">
                        <i class="bi bi-exclamation-triangle-fill"></i>
                        <strong><?= number_format($photoMissing) ?></strong> of
                        <strong><?= number_format($photoTotal) ?></strong> students have no
                        photo<?= $isPhotoRequired
                            ? ' — they cannot record attendance right now.'
                            : '. If you turn this on now, they will not be able to record attendance.' ?>
                    </p>
                <?php endif; ?>

                <form method="post" id="requirePhotoForm">
                    <input type="hidden" name="require_photo_status" id="require_photo_status"
                        value="<?= $isPhotoRequired ? '1' : '0' ?>">
                    <div class="toggle-container">
                        <div class="toggle-wrap">
                            <input class="toggle-input" id="require-photo-toggle" type="checkbox"
                                <?= $isPhotoRequired ? 'checked' : '' ?> />
                            <label class="toggle-track" for="require-photo-toggle">
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
    <script src="<?= asset('../assets/js/requirePhoto.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>
    <script src="<?= asset('../assets/js/userManagement.js') ?>"></script>
</body>

</html>