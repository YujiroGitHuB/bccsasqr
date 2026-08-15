<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

// This page had no role check at all — any signed-in instructor could
// read the database's table sizes and storage usage.
requirePermission('db.monitor');

// Get the active database name
$dbname = $conn->query("SELECT DATABASE()")->fetch_row()[0];

// Get total database size in MB
$sql = "SELECT
            table_schema AS 'Database',
            SUM(data_length + index_length) / 1024 / 1024 AS 'Size_MB',
            SUM(data_length) / 1024 / 1024 AS 'Data_MB',
            SUM(index_length) / 1024 / 1024 AS 'Index_MB'
        FROM information_schema.tables
        WHERE table_schema = '$dbname'
        GROUP BY table_schema";

$result = $conn->query($sql);
$dbSize = $result->fetch_assoc() ?: ['Size_MB' => 0, 'Data_MB' => 0, 'Index_MB' => 0];

// Get per-table sizes
$sql2 = "SELECT
            table_name AS 'Table',
            ROUND((data_length + index_length) / 1024 / 1024, 4) AS 'Size_MB',
            table_rows AS 'Rows'
         FROM information_schema.tables
         WHERE table_schema = '$dbname'
         ORDER BY (data_length + index_length) DESC";

$tables = $conn->query($sql2);

// Read into an array rather than straight into the markup: the stat
// cards above the table need the count and the row total, and they
// are printed before the table is.
$tableList = [];
$totalRows = 0;
while ($row = $tables->fetch_assoc()) {
    $tableList[] = $row;
    $totalRows  += (int) $row['Rows'];
}

// Limit config (InfinityFree = 10MB)
$limit_mb = 10;
$used_mb  = round($dbSize['Size_MB'], 4);
$data_mb  = round($dbSize['Data_MB'], 4);
$index_mb = round($dbSize['Index_MB'], 4);
$free_mb  = round(max($limit_mb - $used_mb, 0), 4);
$percent  = $limit_mb > 0 ? round(($used_mb / $limit_mb) * 100, 2) : 0;

// Share of the limit taken by each half, for the stacked bar.
$dataPct  = $limit_mb > 0 ? min(($data_mb / $limit_mb) * 100, 100) : 0;
$indexPct = $limit_mb > 0 ? min(($index_mb / $limit_mb) * 100, 100) : 0;
$freePct  = max(100 - $dataPct - $indexPct, 0);

// State drives the whole page — the ring, the alert strip, the
// free-space card — through one class on the wrapper. See the note
// at the top of assets/css/db-monitor.css.
if ($percent >= 90) {
    $state      = 'is-danger';
    $stateCard  = 'red';
    $stateIcon  = 'bi-exclamation-octagon-fill';
    $stateTitle = 'CRITICAL:';
    $stateText  = 'Database is almost full. Clean up old records or upgrade the plan immediately.';
} elseif ($percent >= 70) {
    $state      = 'is-warn';
    $stateCard  = 'amber';
    $stateIcon  = 'bi-exclamation-triangle-fill';
    $stateTitle = 'WARNING:';
    $stateText  = 'Usage is above 70%. Monitor closely and plan a cleanup.';
} else {
    $state      = 'is-safe';
    $stateCard  = 'green';
    $stateIcon  = 'bi-shield-check';
    $stateTitle = 'SAFE:';
    $stateText  = 'Database size is within acceptable limits.';
}

// Ring geometry. r=52 on a 120-unit box → circumference 2πr; the dash
// length is the only figure that has to be printed inline, because no
// stylesheet can know the percentage.
$ringCirc = 2 * M_PI * 52;
$ringDash = round($ringCirc * min($percent, 100) / 100, 2);
?>
<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/db-monitor.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content dbm-page <?= $state ?>" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="backup-page-header">
            <h2><i class="bi bi-activity"></i> Database Monitor</h2>
            <span class="dbm-db-badge">
                <i class="bi bi-hdd-fill"></i> <?= htmlspecialchars($dbname) ?>
            </span>
        </div>

        <!-- ── Usage hero ── -->
        <div class="dbm-hero">
            <div class="dbm-gauge">
                <svg viewBox="0 0 120 120" role="img"
                    aria-label="<?= $percent ?> percent of the <?= $limit_mb ?> MB limit used">
                    <circle class="dbm-ring-track" cx="60" cy="60" r="52"></circle>
                    <circle class="dbm-ring-value" cx="60" cy="60" r="52"
                        style="stroke-dasharray: <?= $ringDash ?> 999"></circle>
                </svg>
                <div class="dbm-gauge-center" aria-hidden="true">
                    <span class="dbm-gauge-pct"><?= $percent ?>%</span>
                    <span class="dbm-gauge-sub">used</span>
                </div>
            </div>

            <div class="dbm-hero-body">
                <div class="dbm-hero-label">Overall Usage</div>
                <div class="dbm-hero-figure">
                    <?= $used_mb ?> <small>MB of <?= $limit_mb ?> MB</small>
                </div>

                <div class="dbm-stack" role="presentation">
                    <div class="dbm-seg is-data" style="width: <?= $dataPct ?>%"></div>
                    <div class="dbm-seg is-index" style="width: <?= $indexPct ?>%"></div>
                    <div class="dbm-seg" style="width: <?= $freePct ?>%"></div>
                </div>

                <ul class="dbm-legend">
                    <li><span class="dbm-dot is-data"></span> Data <b><?= $data_mb ?> MB</b></li>
                    <li><span class="dbm-dot is-index"></span> Index <b><?= $index_mb ?> MB</b></li>
                    <li><span class="dbm-dot is-free"></span> Free <b><?= $free_mb ?> MB</b></li>
                </ul>

                <div class="dbm-alert">
                    <i class="bi <?= $stateIcon ?>"></i>
                    <div><strong><?= $stateTitle ?></strong> <?= $stateText ?></div>
                </div>
            </div>
        </div>

        <!-- ── Stat Cards ── -->
        <div class="stat-grid">
            <div class="stat-card blue">
                <div class="stat-icon"><i class="bi bi-table"></i></div>
                <div class="stat-label">Tables</div>
                <div class="stat-value"><?= count($tableList) ?></div>
            </div>
            <div class="stat-card cyan">
                <div class="stat-icon"><i class="bi bi-list-ol"></i></div>
                <div class="stat-label">Total Rows</div>
                <div class="stat-value"><?= number_format($totalRows) ?></div>
            </div>
            <div class="stat-card <?= $stateCard ?>">
                <div class="stat-icon"><i class="bi bi-hdd-fill"></i></div>
                <div class="stat-label">Free Space</div>
                <div class="stat-value"><?= $free_mb ?><small> MB</small></div>
            </div>
            <div class="stat-card red">
                <div class="stat-icon"><i class="bi bi-bar-chart-fill"></i></div>
                <div class="stat-label">Largest Table</div>
                <div class="stat-value sm" title="<?= $tableList ? htmlspecialchars($tableList[0]['Table']) . ' — ' . $tableList[0]['Size_MB'] . ' MB' : '' ?>">
                    <?= $tableList ? htmlspecialchars($tableList[0]['Table']) : '—' ?>
                </div>
            </div>
        </div>

        <!-- ── Table Section ── -->
        <div class="section-header">
            <span class="section-title">
                Per Table Breakdown
                <span style="opacity:.5;font-size:.65rem"><?= count($tableList) ?> tables</span>
            </span>
            <a href="db_monitor.php" class="dbm-refresh">
                <i class="bi bi-arrow-clockwise"></i> Refresh
            </a>
        </div>

        <div class="table-card">
            <table class="table mb-0">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Table Name</th>
                        <th>Size</th>
                        <th>Share of DB</th>
                        <th class="text-end">Rows</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($tableList)): ?>
                        <tr>
                            <td colspan="5">
                                <div class="empty-state">
                                    <i class="bi bi-inbox"></i>
                                    No tables found in this database.
                                </div>
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($tableList as $i => $row): ?>
                            <?php $share = $used_mb > 0 ? min(($row['Size_MB'] / $used_mb) * 100, 100) : 0; ?>
                            <tr>
                                <td class="dbm-rank"><?= $i + 1 ?></td>
                                <td>
                                    <span class="dbm-tname">
                                        <i class="bi bi-table"></i><?= htmlspecialchars($row['Table']) ?>
                                    </span>
                                    <?php if ($i === 0): ?><span class="badge-largest">largest</span><?php endif; ?>
                                </td>
                                <td><span class="badge-size"><?= $row['Size_MB'] ?> MB</span></td>
                                <td>
                                    <div class="dbm-share">
                                        <div class="dbm-share-track">
                                            <div class="dbm-share-fill" style="width: <?= round($share, 2) ?>%"></div>
                                        </div>
                                        <span class="dbm-share-pct"><?= round($share, 1) ?>%</span>
                                    </div>
                                </td>
                                <td class="text-end dbm-num"><?= number_format((int) $row['Rows']) ?></td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

        <div class="dbm-footnote">
            <span><i class="bi bi-clock-history"></i> Last checked: <?= date('M d, Y h:i:s A') ?></span>
            <span><i class="bi bi-info-circle"></i> Row counts are InnoDB estimates from information_schema.</span>
        </div>

    </div><!-- /content -->

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>
</body>

</html>

<?php $conn->close(); ?>
