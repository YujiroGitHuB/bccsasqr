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

$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system        = mysqli_fetch_assoc($systemQuery);
$systemName    = $system['system_name']    ?? '';
$systemAcronym = $system['system_acronym'] ?? '';
$systemLogo    = $system['logo']           ?? '';

$BACKUP_DIR  = __DIR__ . "/../backups/";
$LOG_FILE    = __DIR__ . "/../backups/backup_log.txt";
$MAX_BACKUPS = 30;
$DB_NAME     = $conn->query("SELECT DATABASE()")->fetch_row()[0];

if (!is_dir($BACKUP_DIR)) mkdir($BACKUP_DIR, 0755, true);

function generateSqlBackup($conn, $dbName)
{
    $sql  = "-- ============================================\n";
    $sql .= "-- Database Backup: `$dbName`\n";
    $sql .= "-- Generated: " . date('Y-m-d H:i:s') . "\n";
    $sql .= "-- ============================================\n\n";
    $sql .= "SET FOREIGN_KEY_CHECKS=0;\nSET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';\nSET NAMES utf8mb4;\n\n";

    $tables = [];
    $result = $conn->query("SHOW TABLES");
    while ($row = $result->fetch_row()) $tables[] = $row[0];

    foreach ($tables as $table) {
        $sql .= "-- Table: `$table`\n";
        $sql .= "DROP TABLE IF EXISTS `$table`;\n";
        $createResult = $conn->query("SHOW CREATE TABLE `$table`");
        $createRow    = $createResult->fetch_row();
        $sql .= $createRow[1] . ";\n\n";

        $dataResult = $conn->query("SELECT * FROM `$table`");
        if ($dataResult->num_rows > 0) {
            $sql .= "-- Data for `$table` ({$dataResult->num_rows} rows)\n";
            $fields = [];
            $fi = $conn->query("SHOW COLUMNS FROM `$table`");
            while ($col = $fi->fetch_assoc()) $fields[] = "`{$col['Field']}`";
            $fl = implode(", ", $fields);
            $batch = [];
            while ($row = $dataResult->fetch_row()) {
                $vals = array_map(fn($v) => $v === null ? 'NULL' : "'" . $conn->real_escape_string($v) . "'", $row);
                $batch[] = "(" . implode(", ", $vals) . ")";
                if (count($batch) >= 100) {
                    $sql .= "INSERT INTO `$table` ($fl) VALUES\n" . implode(",\n", $batch) . ";\n";
                    $batch = [];
                }
            }
            if (!empty($batch)) $sql .= "INSERT INTO `$table` ($fl) VALUES\n" . implode(",\n", $batch) . ";\n";
            $sql .= "\n";
        }
    }
    $sql .= "SET FOREIGN_KEY_CHECKS=1;\n-- End of Backup\n";
    return $sql;
}

if (isset($_POST['ajax_action'])) {
    header('Content-Type: application/json');

    if ($_POST['ajax_action'] === 'backup_now') {
        try {
            $filename   = 'backup_' . date('Y-m-d_H-i-s') . '.sql';
            $filepath   = $BACKUP_DIR . $filename;
            file_put_contents($filepath, generateSqlBackup($conn, $DB_NAME));
            $size = round(filesize($filepath) / 1024, 2);
            file_put_contents($LOG_FILE, "[" . date('Y-m-d H:i:s') . "] [SUCCESS] $filename ({$size} KB)\n", FILE_APPEND);
            $all = glob($BACKUP_DIR . '*.sql') ?: [];
            if (count($all) > $MAX_BACKUPS) {
                usort($all, fn($a, $b) => filemtime($a) - filemtime($b));
                foreach (array_slice($all, 0, count($all) - $MAX_BACKUPS) as $o) unlink($o);
            }
            echo json_encode(['status' => 'success', 'message' => "Backup created! ({$size} KB)", 'filename' => $filename]);
        } catch (Exception $e) {
            file_put_contents($LOG_FILE, "[" . date('Y-m-d H:i:s') . "] [FAILED] " . $e->getMessage() . "\n", FILE_APPEND);
            echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
        }
        exit;
    }

    if ($_POST['ajax_action'] === 'delete_backup' && isset($_POST['file'])) {
        $del = $BACKUP_DIR . basename($_POST['file']);
        if (file_exists($del) && str_ends_with($del, '.sql')) {
            unlink($del);
            file_put_contents($LOG_FILE, "[" . date('Y-m-d H:i:s') . "] [DELETED] " . basename($_POST['file']) . "\n", FILE_APPEND);
            echo json_encode(['status' => 'success', 'message' => 'Deleted.']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'File not found.']);
        }
        exit;
    }

    if ($_POST['ajax_action'] === 'get_backups') {
        $b = glob($BACKUP_DIR . '*.sql') ?: [];
        usort($b, fn($a, $b) => filemtime($b) - filemtime($a));
        $list = array_map(fn($f) => ['name' => basename($f), 'size' => round(filesize($f) / 1024, 2), 'date' => date('M d, Y h:i A', filemtime($f))], $b);
        echo json_encode(['backups' => $list, 'total_kb' => array_sum(array_column($list, 'size'))]);
        exit;
    }
    exit;
}

if (isset($_GET['download'])) {
    $dl = $BACKUP_DIR . basename($_GET['download']);
    if (file_exists($dl) && str_ends_with($dl, '.sql')) {
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($dl) . '"');
        header('Content-Length: ' . filesize($dl));
        readfile($dl);
        exit;
    }
}

$backups      = glob($BACKUP_DIR . '*.sql') ?: [];
$totalCount   = count($backups);
$totalSize    = $totalCount ? round(array_sum(array_map('filesize', $backups)) / 1024, 2) : 0;
usort($backups, fn($a, $b) => filemtime($b) - filemtime($a));
$latestBackup = $totalCount ? date('M d, Y h:i A', filemtime($backups[0])) : 'None yet';
$logs = [];
if (file_exists($LOG_FILE)) {
    $lines = file($LOG_FILE, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    $logs  = array_slice(array_reverse($lines), 0, 10);
}
?>
<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="backup-page-header">
            <h2><i class="bi bi-database-fill-gear"></i> Database Backup</h2>
            <span class="hosting-badge">
                <i class="bi bi-check-circle-fill"></i> Pure PHP — Shared Hosting Compatible
            </span>
        </div>

        <!-- ── Stat Cards ── -->
        <div class="stat-grid">
            <div class="stat-card blue">
                <div class="stat-icon"><i class="bi bi-archive-fill"></i></div>
                <div class="stat-label">Total Backups</div>
                <div class="stat-value" id="statCount"><?= $totalCount ?></div>
            </div>
            <div class="stat-card green">
                <div class="stat-icon"><i class="bi bi-hdd-fill"></i></div>
                <div class="stat-label">Total Size</div>
                <div class="stat-value" id="statSize">
                    <?= $totalSize ?><small style="font-size:1rem;font-weight:500;opacity:.6"> KB</small>
                </div>
            </div>
            <div class="stat-card cyan">
                <div class="stat-icon"><i class="bi bi-clock-history"></i></div>
                <div class="stat-label">Latest Backup</div>
                <div class="stat-value sm" id="statLatest"><?= $latestBackup ?></div>
            </div>
        </div>

        <!-- ── Table Section ── -->
        <div class="section-header">
            <span class="section-title">
                Backup Files &nbsp;<span style="opacity:.4;font-size:.65rem">DB: <?= htmlspecialchars($DB_NAME) ?></span>
            </span>
            <button class="btn-backup" id="btnBackupNow">
                <i class="bi bi-database-add"></i> Backup Now
            </button>
        </div>

        <div class="table-card">
            <table class="table mb-0">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Filename</th>
                        <th>Size</th>
                        <th>Date Created</th>
                        <th class="text-center">Actions</th>
                    </tr>
                </thead>
                <tbody id="backupTbody">
                    <?php if (empty($backups)): ?>
                        <tr>
                            <td colspan="5">
                                <div class="empty-state">
                                    <i class="bi bi-inbox"></i>
                                    No backups yet. Click <strong>Backup Now</strong> to create one.
                                </div>
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($backups as $i => $file): ?>
                            <tr>
                                <td class="text-muted" style="font-size:.8rem"><?= $i + 1 ?></td>
                                <td>
                                    <span class="file-name">
                                        <i class="bi bi-file-earmark-text me-1" style="color:#fbbf24"></i>
                                        <?= htmlspecialchars(basename($file)) ?>
                                    </span>
                                    <?php if ($i === 0): ?><span class="badge-latest">latest</span><?php endif; ?>
                                </td>
                                <td><span class="badge-size"><?= round(filesize($file) / 1024, 2) ?> KB</span></td>
                                <td style="font-size:.82rem; color:rgba(255,255,255,.45)"><?= date('M d, Y  h:i A', filemtime($file)) ?></td>
                                <td class="text-center">
                                    <div class="d-flex justify-content-center gap-2">
                                        <a href="?download=<?= urlencode(basename($file)) ?>" class="btn-dl">
                                            <i class="bi bi-download"></i>
                                        </a>
                                        <button class="btn-del btn-delete" data-file="<?= htmlspecialchars(basename($file)) ?>">
                                            <i class="bi bi-trash3"></i>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

        <!-- ── Log ── -->
        <div class="log-card">
            <div class="log-header">
                <i class="bi bi-terminal"></i> Backup Log
                <span style="opacity:.5;font-weight:400;font-size:.65rem">(recent 10)</span>
            </div>
            <div class="log-body">
                <?php if (empty($logs)): ?>
                    <span style="color:rgba(255,255,255,.2)">No logs yet.</span>
                <?php else: ?>
                    <?php foreach ($logs as $line): ?>
                        <div class="<?= str_contains($line, 'SUCCESS') ? 'log-success' : (str_contains($line, 'FAILED') ? 'log-failed' : (str_contains($line, 'DELETED') ? 'log-deleted' : '')) ?>">
                            <?= htmlspecialchars($line) ?>
                        </div>
                    <?php endforeach; ?>
                <?php endif; ?>
            </div>
        </div>

    </div><!-- /content -->

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>

    <script>
        document.getElementById('btnBackupNow').addEventListener('click', function() {
            Swal.fire({
                title: 'Create Backup?',
                text: 'Gagawa ng bagong .sql backup file ng database.',
                icon: 'question',
                showCancelButton: true,
                confirmButtonColor: '#3b82f6',
                confirmButtonText: '<i class="bi bi-database-add"></i> Yes, Backup Now!',
                cancelButtonText: 'Cancel'
            }).then(result => {
                if (!result.isConfirmed) return;
                Swal.fire({
                    title: 'Creating Backup...',
                    html: 'Please wait...',
                    allowOutsideClick: false,
                    didOpen: () => Swal.showLoading()
                });
                fetch('backup.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/x-www-form-urlencoded'
                        },
                        body: 'ajax_action=backup_now'
                    })
                    .then(r => r.json())
                    .then(data => {
                        if (data.status === 'success') {
                            Swal.fire({
                                icon: 'success',
                                title: 'Backup Created!',
                                text: data.message,
                                timer: 2500,
                                showConfirmButton: false
                            });
                            refreshTable();
                        } else {
                            Swal.fire({
                                icon: 'error',
                                title: 'Backup Failed',
                                text: data.message
                            });
                        }
                    })
                    .catch(() => Swal.fire({
                        icon: 'error',
                        title: 'Error',
                        text: 'Something went wrong.'
                    }));
            });
        });

        document.getElementById('backupTbody').addEventListener('click', function(e) {
            const btn = e.target.closest('.btn-delete');
            if (!btn) return;
            const file = btn.dataset.file;
            Swal.fire({
                title: 'Delete Backup?',
                html: `<code style="font-size:.8rem">${file}</code>`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#ef4444',
                confirmButtonText: 'Yes, Delete!'
            }).then(result => {
                if (!result.isConfirmed) return;
                fetch('backup.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/x-www-form-urlencoded'
                        },
                        body: `ajax_action=delete_backup&file=${encodeURIComponent(file)}`
                    })
                    .then(r => r.json())
                    .then(data => {
                        if (data.status === 'success') {
                            Swal.fire({
                                icon: 'success',
                                title: 'Deleted!',
                                timer: 1500,
                                showConfirmButton: false
                            });
                            refreshTable();
                        } else {
                            Swal.fire({
                                icon: 'error',
                                title: 'Error',
                                text: data.message
                            });
                        }
                    });
            });
        });

        function refreshTable() {
            fetch('backup.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded'
                    },
                    body: 'ajax_action=get_backups'
                })
                .then(r => r.json())
                .then(data => {
                    const backups = data.backups;
                    document.getElementById('statCount').textContent = backups.length;
                    document.getElementById('statSize').innerHTML = `${data.total_kb}<small style="font-size:1rem;font-weight:500;opacity:.6"> KB</small>`;
                    document.getElementById('statLatest').textContent = backups.length ? backups[0].date : 'None yet';

                    if (!backups.length) {
                        document.getElementById('backupTbody').innerHTML =
                            `<tr><td colspan="5"><div class="empty-state"><i class="bi bi-inbox"></i>No backups yet.</div></td></tr>`;
                        return;
                    }
                    document.getElementById('backupTbody').innerHTML = backups.map((b, i) => `
                <tr>
                    <td class="text-muted" style="font-size:.8rem">${i+1}</td>
                    <td>
                        <span class="file-name"><i class="bi bi-file-earmark-text me-1" style="color:#fbbf24"></i>${escHtml(b.name)}</span>
                        ${i===0?'<span class="badge-latest">latest</span>':''}
                    </td>
                    <td><span class="badge-size">${b.size} KB</span></td>
                    <td style="font-size:.82rem;color:rgba(255,255,255,.45)">${b.date}</td>
                    <td class="text-center">
                        <div class="d-flex justify-content-center gap-2">
                            <a href="backup.php?download=${encodeURIComponent(b.name)}" class="btn-dl"><i class="bi bi-download"></i></a>
                            <button class="btn-del btn-delete" data-file="${escHtml(b.name)}"><i class="bi bi-trash3"></i></button>
                        </div>
                    </td>
                </tr>`).join('');
                    setTimeout(() => location.reload(), 1800);
                });
        }

        function escHtml(s) {
            return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        }
    </script>
</body>

</html>