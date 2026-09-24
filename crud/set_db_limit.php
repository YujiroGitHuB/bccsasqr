<?php
// ============================================================
// Sets the database allowance the Database Monitor measures
// against — the size shown in hPanel for this database.
//
// It changes nothing about the database itself, only the number
// the gauge divides by. It was a literal in pages/db_monitor.php,
// which meant a plan change needed a code change and a deploy.
//
// Accepts (POST):
//   value  a positive number, decimals allowed ("1.5")
//   unit   MB | GB
//
// Stored in MB in attendance_settings under db_limit_mb.
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";

header('Content-Type: application/json');

if (empty($_SESSION['user_id'])) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('sign-in');
    echo json_encode(['success' => false, 'message' => 'Not logged in']);
    exit;
}

requirePermissionJson('db.monitor');

// Seeing the monitor can be given to an instructor; deciding what the
// hosting plan allows is the administrator's call. The button is only
// drawn for admins — this is the check that counts.
if (!isAdmin()) {
    require_once __DIR__ . '/../includes/security_log.php';
    security_denied('admin: database size limit');
    echo json_encode(['success' => false, 'message' => 'Only an administrator can change the database limit.']);
    exit;
}

$value = (float) ($_POST['value'] ?? 0);
$unit  = strtoupper(trim($_POST['unit'] ?? 'MB')) === 'GB' ? 'GB' : 'MB';
$mb    = (int) round($unit === 'GB' ? $value * 1024 : $value);

// 1 MB to 1 TB. Below that the gauge is meaningless; above it is not a
// shared-hosting database.
if ($mb < 1 || $mb > 1024 * 1024) {
    echo json_encode(['success' => false, 'message' => 'Enter a size between 1 MB and 1024 GB.']);
    exit;
}

$stmt = $conn->prepare("
    INSERT INTO attendance_settings (setting_key, setting_value, updated_at)
    VALUES ('db_limit_mb', ?, NOW())
    ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()
");
$val = (string) $mb;
$stmt->bind_param('s', $val);

if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Could not save the limit. Please try again.']);
    exit;
}

echo json_encode(['success' => true, 'limit_mb' => $mb]);

$conn->close();
