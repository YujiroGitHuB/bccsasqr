<?php require_once __DIR__ . '/../includes/asset.php';

// ============================================================
// "Bakit hindi lumalabas ang selfie?"
//
// Ang tampok na ito ay may anim na bagay na dapat sabay-sabay na
// totoo: ang migration, ang setting, ang folder, ang HTTPS, ang
// camera ng telepono, at ang pagkakataong mapili ang estudyante.
// Kapag isa rito ang kulang, WALANG lumalabas — walang error,
// walang mensahe, dumadaan lang ang pagsusumite na parang walang
// tampok. Sinadya iyon (mas mabuti ang tahimik na patay kaysa sa
// basag na attendance), pero ang kapalit ay walang masabing
// dahilan ang sistema.
//
// Ito ang nagsasabi. Isang pahina, anim na sagot.
//
// Hindi ito bahagi ng pang-araw-araw na paggamit — kasangkapan
// ito sa pag-setup. Ligtas itong tanggalin kapag tumatakbo na ang
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

/** Umiiral ba ang column? */
function has_column(mysqli $conn, string $table, string $col): bool
{
    try {
        $stmt = $conn->prepare("
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ? LIMIT 1
        ");
        $stmt->bind_param("ss", $table, $col);
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
$hasRoom  = has_column($conn, 'attendance_links_tbl', 'require_room_code');
$hasSeed  = has_column($conn, 'attendance_links_tbl', 'room_code_secret');
$migrated = $hasAudit && $hasRate && $hasRoom && $hasSeed;

$checks[] = [
    'ok'    => $migrated,
    'title' => 'The migration has been run',
    'good'  => 'All four pieces are in the database.',
    'bad'   => 'Open phpMyAdmin, select this database, go to the SQL tab, paste the whole of '
             . '<code>migrations/2026-09-09_add_attendance_integrity.sql</code> and press Go. '
             . 'Uploading the file does not run it.',
    'detail' => 'attendance_audit_tbl: ' . ($hasAudit ? 'yes' : 'MISSING')
              . ' · attendance_ratelimit_tbl: ' . ($hasRate ? 'yes' : 'MISSING')
              . ' · require_room_code: ' . ($hasRoom ? 'yes' : 'MISSING')
              . ' · room_code_secret: ' . ($hasSeed ? 'yes' : 'MISSING'),
];

// ── 2. Ang setting ───────────────────────────────────────────
$rateRaw = setting_row($conn, 'selfie_spot_rate');
$rate    = (int) ($rateRaw ?? 0);

$checks[] = [
    'ok'    => $rateRaw !== null && $rate > 0,
    'title' => 'Selfie Spot Check is switched on',
    'good'  => 'Set to ' . $rate . '% of submissions.',
    'bad'   => $rateRaw === null
             ? 'There is no <code>selfie_spot_rate</code> row at all, so it falls back to 0 — off. This comes from the migration above.'
             : 'It is set to 0, which turns the feature off. Raise it under Settings &rsaquo; Attendance rules.',
    'detail' => 'attendance_settings.selfie_spot_rate = ' . ($rateRaw === null ? '(no row)' : $rateRaw),
];

// ── 3. Ang folder ────────────────────────────────────────────
//
// Ito ang tahimik na pumapalya sa isang shared host: tama ang
// lahat, pero hindi makasulat ang PHP sa uploads/, kaya ang
// larawang naipadala na ay hindi na-save.
$uploadsDir = __DIR__ . '/../uploads';
$selfieDir  = $uploadsDir . '/selfies';
$canWrite   = false;
$writeNote  = '';

if (!is_dir($uploadsDir)) {
    $writeNote = 'uploads/ does not exist on the server.';
} elseif (!is_writable($uploadsDir)) {
    $writeNote = 'uploads/ exists but PHP cannot write into it.';
} else {
    // Ang tunay na tseke ay ang pagsulat mismo, hindi ang
    // is_writable(): magkaiba ang sinasabi ng dalawa sa ilang
    // shared host.
    if (!is_dir($selfieDir)) @mkdir($selfieDir, 0755, true);

    if (!is_dir($selfieDir)) {
        $writeNote = 'uploads/selfies/ could not be created.';
    } else {
        $probe = $selfieDir . '/.probe';
        if (@file_put_contents($probe, 'x') !== false) {
            @unlink($probe);
            $canWrite  = true;
            $writeNote = 'uploads/selfies/ exists and a test file was written and removed.';
        } else {
            $writeNote = 'uploads/selfies/ exists but a test file could not be written.';
        }
    }
}

$checks[] = [
    'ok'     => $canWrite,
    'title'  => 'The server can save the photos',
    'good'   => $writeNote,
    'bad'    => $writeNote . ' Set the folder permission to 755 in the file manager.',
    'detail' => 'uploads/selfies/',
];

// ── 4. Ang gamit sa larawan ──────────────────────────────────
$hasGd = function_exists('getimagesizefromstring');

$checks[] = [
    'ok'     => $hasGd,
    'title'  => 'PHP can check that an upload really is a photo',
    'good'   => 'getimagesizefromstring() is available.',
    'bad'    => 'getimagesizefromstring() is missing, so every selfie is rejected as "not a photo".',
    'detail' => 'PHP ' . PHP_VERSION,
];

// ── 5. HTTPS ────────────────────────────────────────────────
$https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
      || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');

$checks[] = [
    'ok'     => $https,
    'title'  => 'The page is served over HTTPS',
    'good'   => 'Browsers will allow the camera here.',
    'bad'    => 'You opened this over plain http. No browser will open a camera on http, '
              . 'so the photo check can never appear. Use the https:// address.',
    'detail' => ($https ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? ''),
];

// ── 6. Ang pagkakataon ───────────────────────────────────────
//
// Kahit tama ang lahat, hindi lumalabas ang camera sa taong hindi
// napili — at hindi ito nagbabago sa buong araw, kaya ang pag-
// refresh ay walang naidudulot. Ito ang huling dahilan, at ito
// ang pinakamadalas mapagkamalang sira.
$sampleAsked = [];
$sampleTotal = 0;

if ($migrated && $rate > 0) {
    try {
        $q = $conn->query("
            SELECT l.short_code, ss.student_no
            FROM attendance_links_tbl l
            JOIN student_subjects_tbl ss ON ss.subject_code = l.subject_code
            WHERE l.is_active = 1
            LIMIT 60
        ");
        while ($row = $q->fetch_assoc()) {
            $sampleTotal++;
            if (selfie_is_required($conn, $row['student_no'], $row['short_code'], $rate, 0)) {
                $sampleAsked[] = $row['student_no'] . ' → ' . $row['short_code'];
            }
        }
    } catch (Throwable $e) {
        // Walang magagawa; ipinapakita lang ang zero sa ibaba.
    }
}
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
        .ati-page .cam-out { margin-top: .8rem; font-size: .84rem; line-height: 1.6; color: var(--ink-3); }
        .ati-page .cam-stage { width: 180px; height: 180px; margin-top: .7rem; border-radius: 14px; overflow: hidden; border: 1px solid var(--ati-line); background: rgba(var(--tint), .05); }
        .ati-page .cam-stage video { width: 100%; height: 100%; object-fit: cover; transform: scaleX(-1); }
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
                    <p>Why the photo check is or is not appearing, in six answers.</p>
                </div>
            </div>

            <div class="ati-card">
                <div class="ati-card-head">
                    <h3><i class="bi bi-list-check"></i> The server side</h3>
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

            <?php if ($migrated && $rate > 0): ?>
                <div class="ati-card">
                    <div class="ati-card-head">
                        <h3><i class="bi bi-dice-3"></i> Who would be asked right now</h3>
                        <span class="ati-count"><?= count($sampleAsked) ?> of <?= $sampleTotal ?></span>
                    </div>
                    <p class="ati-lede">
                        The pick is fixed for the whole day, so refreshing never changes it. If the number
                        you are testing with is not on this list, you will not see the camera today no matter
                        how many times you submit &mdash; that is the feature working, not failing.
                        To see it on demand, set the rate to 100 in Settings, test, then put it back.
                    </p>
                    <?php if (empty($sampleAsked)): ?>
                        <p class="ati-none"><i class="bi bi-info-circle"></i> None of the sampled pairs are picked today.</p>
                    <?php else: ?>
                        <p class="chk-detail" style="margin-top:0 !important">
                            <?= htmlspecialchars(implode(' · ', array_slice($sampleAsked, 0, 40))) ?>
                        </p>
                    <?php endif; ?>
                </div>
            <?php endif; ?>

            <div class="ati-card">
                <div class="ati-card-head">
                    <h3><i class="bi bi-camera-video"></i> This device</h3>
                </div>
                <p class="ati-lede">
                    Open this page on the phone a student would actually use. The button asks for the camera
                    exactly the way the attendance form does.
                </p>
                <button type="button" class="set-btn" id="camTest"><i class="bi bi-camera"></i> Test the camera</button>
                <div class="cam-out" id="camOut"></div>
                <div class="cam-stage" id="camStage" hidden><video id="camVideo" playsinline muted autoplay></video></div>
            </div>

        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/profileUpdate.js') ?>"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script>
        // Ang parehong tatlong tanong na itinatanong ng attendance
        // form, isa-isang sinasagot — dahil ang "walang lumalabas" ay
        // maaaring alinman sa tatlo, at magkaiba ang lunas ng bawat isa.
        document.getElementById('camTest').addEventListener('click', async function () {
            const out = document.getElementById('camOut');
            const lines = [];

            lines.push(row(window.isSecureContext, 'Secure context (https)',
                'The page is not secure, so the camera API is switched off by the browser.'));

            const hasApi = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
            lines.push(row(hasApi, 'navigator.mediaDevices.getUserMedia exists',
                'This browser does not expose the camera API at all. In-app browsers (Facebook, Messenger) are the usual cause — open the link in Chrome or Safari.'));

            out.innerHTML = lines.join('');

            if (!hasApi) return;

            out.innerHTML += '<div>Asking for permission&hellip;</div>';

            try {
                const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false });
                const v = document.getElementById('camVideo');
                v.srcObject = stream;
                document.getElementById('camStage').hidden = false;
                out.innerHTML += row(true, 'Camera opened', '');
                setTimeout(() => {
                    stream.getTracks().forEach(t => t.stop());
                    document.getElementById('camStage').hidden = true;
                    out.innerHTML += '<div class="chk-detail">Camera released.</div>';
                }, 6000);
            } catch (err) {
                out.innerHTML += row(false, 'Camera opened',
                    err.name + ' — ' + (err.name === 'NotAllowedError'
                        ? 'permission was denied. Allow the camera for this site in the browser settings.'
                        : err.name === 'NotFoundError'
                            ? 'this device has no camera.'
                            : err.message));
            }

            function row(ok, label, why) {
                return '<div><span style="color:' + (ok ? '#4ade80' : '#f87171') + '">'
                     + (ok ? '✓' : '✗') + '</span> ' + label
                     + (ok || !why ? '' : ' &mdash; ' + why) + '</div>';
            }
        });
    </script>
</body>

</html>
