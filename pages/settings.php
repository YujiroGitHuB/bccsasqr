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

    // setting_key has a UNIQUE KEY, so one statement is enough — it
    // inserts when absent and updates when present.
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

// Get student photo requirement status (defaults to OFF when there is
// no row yet — see the migration for why)
$photoReqResult = mysqli_query($conn, "SELECT setting_value FROM attendance_settings WHERE setting_key = 'require_student_photo'");
$isPhotoRequired = false;
if ($photoReqResult && mysqli_num_rows($photoReqResult) > 0) {
    $isPhotoRequired = (mysqli_fetch_assoc($photoReqResult)['setting_value'] === '1');
}

// How many students this affects when turned on — the admin needs to
// see it before pressing, because students with no photo will not be
// able to record attendance.
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
    <!-- settings-page.css comes after: the logo picker (.cfg-*) is
         written there and has to beat the .app-modal rules when the
         specificity is equal. -->
    <link rel="stylesheet" href="<?= asset('../assets/css/modal-form.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/settings-page.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content set-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="set-wrap">

            <div class="set-hero">
                <div class="set-hero-icon"><i class="bi bi-sliders"></i></div>
                <div>
                    <h2>Manage Settings</h2>
                    <p>System-wide switches. Changes take effect immediately for everyone.</p>
                </div>
            </div>

            <!-- ══ ACCESS CONTROL ══════════════════════════════ -->
            <div class="set-group-title">Access control</div>
            <div class="set-list">

                <!-- Page Lock -->
                <div class="set-row">
                    <div class="set-icon"><i class="bi bi-shield-lock-fill"></i></div>
                    <div class="set-main">
                        <h3>
                            Page Lock
                            <span class="set-badge <?= $isLocked ? 'off' : 'on' ?>" id="pageLockStatus">
                                <i class="bi bi-<?= $isLocked ? 'lock-fill' : 'unlock-fill' ?>"></i>
                                <?= $isLocked ? 'Locked' : 'Unlocked' ?>
                            </span>
                        </h3>
                        <p>
                            When locked, the QR Generator, QR Scanner, Attendance Tracker,
                            and the registration page stop opening for everyone. Use it
                            outside class hours.
                        </p>
                    </div>
                    <div class="set-control">
                        <form method="post" id="lockForm">
                            <input type="hidden" name="lock_status" id="lock_status" value="<?= $isLocked ? 'true' : 'false' ?>">
                            <div class="toggle-container">
                                <div class="toggle-wrap">
                                    <input class="toggle-input" id="holo-toggle" type="checkbox" <?= $isLocked ? 'checked' : '' ?> />
                                    <label class="toggle-track" for="holo-toggle">
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
                </div>

                <!-- Attendance Lock -->
                <div class="set-row">
                    <div class="set-icon"><i class="bi bi-calendar-check-fill"></i></div>
                    <div class="set-main">
                        <h3>
                            Attendance Lock
                            <span class="set-badge <?= $isAttendanceLocked ? 'off' : 'on' ?>" id="attendanceLockStatus">
                                <i class="bi bi-<?= $isAttendanceLocked ? 'lock-fill' : 'unlock-fill' ?>"></i>
                                <?= $isAttendanceLocked ? 'Locked' : 'Unlocked' ?>
                            </span>
                        </h3>
                        <p>
                            When locked, the shared attendance link stops accepting
                            submissions. Students opening it see a closed notice instead
                            of the form.
                        </p>
                    </div>
                    <div class="set-control">
                        <form method="post" id="attendanceLockForm">
                            <input type="hidden" name="attendance_lock_status" id="attendance_lock_status" value="<?= $isAttendanceLocked ? '1' : '0' ?>">
                            <div class="toggle-container">
                                <div class="toggle-wrap">
                                    <input class="toggle-input" id="attendance-toggle" type="checkbox" <?= $isAttendanceLocked ? 'checked' : '' ?> />
                                    <label class="toggle-track" for="attendance-toggle">
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
                </div>
            </div>

            <!-- ══ ATTENDANCE RULES ════════════════════════════ -->
            <div class="set-group-title">Attendance rules</div>
            <div class="set-list">

                <!-- Student Photo Requirement -->
                <div class="set-row">
                    <div class="set-icon"><i class="bi bi-person-badge-fill"></i></div>
                    <div class="set-main">
                        <h3>
                            Student Photo Requirement
                            <span class="set-badge <?= $isPhotoRequired ? 'strict' : 'muted' ?>" id="photoStatus">
                                <i class="bi bi-<?= $isPhotoRequired ? 'shield-lock-fill' : 'shield-slash' ?>"></i>
                                <?= $isPhotoRequired ? 'Required' : 'Optional' ?>
                            </span>
                        </h3>
                        <p>
                            When ON, students without an uploaded photo cannot record
                            attendance — the instructor has no face to check against the
                            QR being presented. When OFF, the scan still goes through but
                            shows a warning that identity could not be verified.
                        </p>

                        <?php if ($photoMissing > 0): ?>
                            <!-- requirePhoto.js reads this id for the confirmation
                                 text — it used to walk up the DOM from the warning
                                 icon. -->
                            <div class="set-warn <?= $isPhotoRequired ? 'danger' : '' ?>" id="photoWarning">
                                <i class="bi bi-exclamation-triangle-fill"></i>
                                <span>
                                    <strong><?= number_format($photoMissing) ?></strong> of
                                    <strong><?= number_format($photoTotal) ?></strong> students have no
                                    photo<?= $isPhotoRequired
                                        ? ' — they cannot record attendance right now.'
                                        : '. If you turn this on now, they will not be able to record attendance.' ?>
                                </span>
                            </div>
                        <?php endif; ?>
                    </div>
                    <div class="set-control">
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
                </div>
            </div>

            <!-- ══ SYSTEM ══════════════════════════════════════ -->
            <div class="set-group-title">System</div>
            <div class="set-list">
                <div class="set-row">
                    <div class="set-icon"><i class="bi bi-gear-fill"></i></div>
                    <div class="set-main">
                        <h3>System Configuration</h3>
                        <p>
                            The system name, acronym, and logo shown in the sidebar,
                            the browser tab, and on exported reports — plus the
                            copyright footer at the bottom of every page.
                        </p>
                    </div>
                    <div class="set-control">
                        <button class="set-btn" data-bs-toggle="modal" data-bs-target="#systemConfigModal">
                            <i class="bi bi-arrow-repeat"></i> Update System
                        </button>
                    </div>
                </div>
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
