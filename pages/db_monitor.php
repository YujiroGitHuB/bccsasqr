<?php
session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

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
$dbSize = $result->fetch_assoc();

// Get per-table sizes
$sql2 = "SELECT 
            table_name AS 'Table',
            ROUND((data_length + index_length) / 1024 / 1024, 4) AS 'Size_MB',
            table_rows AS 'Rows'
         FROM information_schema.tables
         WHERE table_schema = '$dbname'
         ORDER BY (data_length + index_length) DESC";

$tables = $conn->query($sql2);

// Limit config (InfinityFree = 10MB)
$limit_mb = 10;
$used_mb = round($dbSize['Size_MB'], 4);
$percent = round(($used_mb / $limit_mb) * 100, 2);

// Color based on usage
if ($percent >= 90) $color = '#e74c3c';       // Red - danger
elseif ($percent >= 70) $color = '#f39c12';   // Orange - warning
else $color = '#2ecc71';                       // Green - safe
?>
<!DOCTYPE html>
<html>
<head>
    <title>Database Monitor</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; background: #1e1e2e; color: #cdd6f4; padding: 30px; }
        .card { background: #313244; border-radius: 12px; padding: 20px; margin-bottom: 20px; }
        h2 { color: #cba6f7; }
        .bar-container { background: #45475a; border-radius: 10px; height: 30px; overflow: hidden; }
        .bar { height: 100%; border-radius: 10px; transition: width 0.5s;
               background: <?= $color ?>; width: <?= min($percent, 100) ?>%; }
        .percent { font-size: 24px; font-weight: bold; color: <?= $color ?>; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th { background: #45475a; padding: 10px; text-align: left; }
        td { padding: 8px 10px; border-bottom: 1px solid #45475a; }
        tr:hover { background: #45475a; }
        .alert { padding: 12px 16px; border-radius: 8px; margin-top: 10px; }
        .alert-danger { background: #e74c3c33; border-left: 4px solid #e74c3c; }
        .alert-warning { background: #f39c1233; border-left: 4px solid #f39c12; }
        .alert-success { background: #2ecc7133; border-left: 4px solid #2ecc71; }
    </style>
</head>
<body>
    <h2>Database Monitor — <?= $dbname ?></h2>

    <div class="card">
        <h3>Overall Usage</h3>
        <p class="percent"><?= $used_mb ?> MB / <?= $limit_mb ?> MB (<?= $percent ?>%)</p>
        <div class="bar-container">
            <div class="bar"></div>
        </div>

        <?php if ($percent >= 90): ?>
            <div class="alert alert-danger"><strong>CRITICAL:</strong> Database is almost full. Please clean up or upgrade immediately.</div>
        <?php elseif ($percent >= 70): ?>
            <div class="alert alert-warning"><strong>WARNING:</strong> Usage is above 70%. Monitor closely.</div>
        <?php else: ?>
            <div class="alert alert-success"><strong>SAFE:</strong> Database size is within acceptable limits.</div>
        <?php endif; ?>

        <p>
            Data: <strong><?= round($dbSize['Data_MB'], 4) ?> MB</strong> &nbsp;|&nbsp;
            Index: <strong><?= round($dbSize['Index_MB'], 4) ?> MB</strong>
        </p>
    </div>

    <div class="card">
        <h3>Per Table Breakdown</h3>
        <table>
            <tr>
                <th>Table Name</th>
                <th>Size (MB)</th>
                <th>Rows</th>
            </tr>
            <?php while ($row = $tables->fetch_assoc()): ?>
            <tr>
                <td><?= $row['Table'] ?></td>
                <td><?= $row['Size_MB'] ?></td>
                <td><?= number_format($row['Rows']) ?></td>
            </tr>
            <?php endwhile; ?>
        </table>
    </div>

    <small style="color:#6c7086;">Last checked: <?= date('Y-m-d H:i:s') ?></small>
</body>
</html>

<?php $conn->close(); ?>