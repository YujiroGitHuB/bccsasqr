<?php require_once __DIR__ . '/../includes/asset.php';

// ============================================================
// "Tumatakbo na ba ang device check?"
//
// Ang tampok ay may dalawang bagay na dapat sabay na totoo: ang
// migration at ang setting. Kapag isa rito ang kulang, WALANG
// lumalabas — walang error, walang mensahe, dumadaan lang ang
// pagsusumite na parang walang tampok. Sinadya iyon (mas mabuti ang
// tahimik na patay kaysa sa basag na attendance), pero ang kapalit
// ay walang masabing dahilan ang sistema.
//
// Ito ang nagsasabi.
//
// Hindi ito bahagi ng pang-araw-araw na paggamit — kasangkapan ito
// sa pag-setup. Ligtas itong tanggalin kapag tumatakbo na ang
// lahat; walang ibang file na tumatawag dito.
// ============================================================

session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";

// Nakikita ng nag-a-ayos ng setup, hindi ng lahat: sinasabi nito
// kung anong talahanayan ang mayroon at wala ang database.
requireAnyPermission(['settings.manage', 'links.manage']);

/** Umiiral ba ang talahanayan? */
function has_table(mysqli $conn, string $name): bool
{
    try {
        $stmt = $conn->prepare("
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1
        ");
        $stmt->bind_param("s", $name);
        $stmt->execute();
        $found = $stmt->get_result()->num_rows > 0;
        $stmt->close();
        return $found;
    } catch (Throwable $e) {
        return false;
    }
}

/** May hilera ba ang setting, at ano ang laman? */
function setting_row(mysqli $conn, string $key): ?string
{
    try {
        $stmt = $conn->prepare("SELECT setting_value FROM attendance_settings WHERE setting_key = ? LIMIT 1");
        $stmt->bind_param("s", $key);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        return $row ? $row['setting_value'] : null;
    } catch (Throwable $e) {
        return null;
    }
}

$checks = [];

// ── 1. Ang migration ─────────────────────────────────────────
$hasAudit = has_table($conn, 'attendance_audit_tbl');
$hasRate  = has_table($conn, 'attendance_ratelimit_tbl');
$migrated = $hasAudit && $hasRate;

$checks[] = [
    'ok'    => $migrated,
    'title' => 'The migration has been run',
    'good'  => 'Both tables are in the database.',
    'bad'   => 'Open phpMyAdmin, select this database, go to the SQL tab, paste the whole of '
             . '<code>migrations/2026-09-09_add_attendance_integrity.sql</code> and press Go. '
             . 'Uploading the file does not run it.',
    'detail' => 'attendance_audit_tbl: ' . ($hasAudit ? 'yes' : 'MISSING')
              . ' · attendance_ratelimit_tbl: ' . ($hasRate ? 'yes' : 'MISSING'),
];

// ── 2. Ang setting ───────────────────────────────────────────
$bindRaw = setting_row($conn, 'device_binding');
$binding = $bindRaw === null ? true : $bindRaw === '1';

$checks[] = [
    'ok'    => $binding,
    'title' => 'One Device, One Student is switched on',
    'good'  => 'A phone that has recorded attendance for one student cannot record it for another today.',
    'bad'   => 'It is switched off, so one phone can submit for as many students as it likes. '
             . 'Turn it back on under Settings &rsaquo; Attendance rules.',
    'detail' => 'attendance_settings.device_binding = ' . ($bindRaw === null ? '(no row — defaults to on)' : $bindRaw),
];

// ── 3. HTTPS ────────────────────────────────────────────────
$https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
      || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');

$checks[] = [
    'ok'     => $https,
    'title'  => 'The page is served over HTTPS',
    'good'   => 'The device cookie is set with the Secure flag.',
    'bad'    => 'You opened this over plain http. Attendance still works, but the device '
              . 'cookie cannot be marked Secure. Use the https:// address.',
    'detail' => ($https ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? ''),
];

?>
<!doctype html>
<html lang="en">

<head>
    <title>Integrity Check</title>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/attendance-integrity.css') ?>">
    <style>
        /* Nasa isang pahinang ito lamang ang mga hugis na ito, at
           itatapon ito kapag tapos na ang setup — kaya rito na rin
           ang estilo, hindi sa isang stylesheet na mananatili. */
        .ati-page .chk { display: flex; gap: .9rem; padding: 1rem 0; border-bottom: 1px solid rgba(var(--tint), .06); }
        .ati-page .chk:last-child { border-bottom: 0; }
        .ati-page .chk-mark { flex-shrink: 0; width: 26px; height: 26px; border-radius: 50%; display: grid; place-items: center; font-size: .95rem; }
        .ati-page .chk-mark.is-ok { color: #4ade80; background: rgba(74, 222, 128, .12); border: 1px solid rgba(74, 222, 128, .3); }
        .ati-page .chk-mark.is-no { color: var(--ati-hot); background: var(--ati-hot-soft); border: 1px solid var(--ati-hot-line); }
        .ati-page .chk-body h4 { margin: 0 0 .2rem; font-size: .92rem; font-weight: 700; color: var(--ink-2); }
        .ati-page .chk-body p { margin: 0; font-size: .84rem; line-height: 1.6; color: var(--ink-3); }
        .ati-page .chk-detail { margin-top: .35rem !important; font-size: .75rem !important; color: var(--ink-4) !important; word-break: break-word; }
        .ati-page .chk-detail code, .ati-page .chk-body code { padding: .1rem .3rem; border-radius: 5px; background: rgba(var(--tint), .06); color: var(--ati-ink); }
                            </style>
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content ati-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="container-fluid px-3 px-md-4 py-3">

            <div class="ati-hero">
                <div class="ati-hero-icon"><i class="bi bi-clipboard-pulse"></i></div>
                <div class="ati-hero-text">
                    <h2>Integrity Check</h2>
                    <p>Whether the device check is actually running, in three answers.</p>
                </div>
            </div>

            <div class="ati-card">
                <div class="ati-card-head">
                    <h3><i class="bi bi-list-check"></i> Setup</h3>
                </div>

                <?php foreach ($checks as $c): ?>
                    <div class="chk">
                        <div class="chk-mark <?= $c['ok'] ? 'is-ok' : 'is-no' ?>">
                            <i class="bi bi-<?= $c['ok'] ? 'check-lg' : 'x-lg' ?>"></i>
                        </div>
                        <div class="chk-body">
                            <h4><?= htmlspecialchars($c['title']) ?></h4>
                            <p><?= $c['ok'] ? $c['good'] : $c['bad'] ?></p>
                            <p class="chk-detail"><?= $c['detail'] ?></p>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>

        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/profileUpdate.js') ?>"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
</body>

</html>
