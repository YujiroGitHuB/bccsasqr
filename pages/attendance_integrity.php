<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

// links.manage at hindi bagong permission key.
//
// Ang taong gumagawa ng attendance link ang siya ring taong dapat
// makakita kung paano ito ginamit — magkasunod na tanong iyon, hindi
// dalawang tungkulin. At ang bagong key ay magiging hindi ipinagkaloob
// sa lahat sa unang araw: isang pahinang walang makakakita hangga't
// hindi pumapasok ang admin sa bawat instruktor at binubuksan ito nang
// isa-isa. Ang talaang hindi tinitingnan ay walang silbi.
requirePermission('links.manage');

$user_id   = (int) $_SESSION['user_id'];
$is_admin  = ($_SESSION['role'] === 'admin');

// Ilang araw pabalik ang tinitingnan. Ang audit ay itinatago nang
// tatlumpung araw (INTEGRITY_AUDIT_DAYS), kaya walang saysay ang
// mas malayo pa rito.
$days = (int) ($_GET['days'] ?? 7);
if (!in_array($days, [1, 7, 30], true)) $days = 7;

$show = $_GET['show'] ?? 'flagged';
if (!in_array($show, ['flagged', 'selfies', 'all'], true)) $show = 'flagged';

// ── Ang scope ────────────────────────────────────────────────
// Ang admin ay nakikita ang lahat; ang instructor ay ang sarili
// niyang klase lamang. Isang fragment ng SQL at isang parameter,
// ipinapasok sa bawat tanong sa ibaba — kung isa rito ang
// makakalimot nito, makikita ng instruktor ang mga estudyante ng
// ibang guro.
$scopeSql    = $is_admin ? '' : ' AND instructor_id = ? ';
$scopeType   = $is_admin ? '' : 'i';
$scopeParams = $is_admin ? [] : [$user_id];

/**
 * Isang tanong sa attendance_audit_tbl, ligtas kahit wala pa ang
 * talaan.
 *
 * Ang buong pahinang ito ay tungkol sa isang talaang dumarating
 * kasama ng migrations/2026-09-09_add_attendance_integrity.sql. Kung
 * hindi pa iyon napapatakbo, ang tamang ipakita ay isang paalala —
 * hindi isang basag na pahina na walang sinasabi kung ano ang mali.
 */
function audit_query(mysqli $conn, string $sql, string $types, array $params): ?array
{
    try {
        $stmt = $conn->prepare($sql);
        if ($types !== '') $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        return $rows;
    } catch (Throwable $e) {
        error_log('attendance_integrity: ' . $e->getMessage());
        return null;
    }
}

$ready = true;

// ── Mga bilang sa itaas ──────────────────────────────────────
$totals = audit_query($conn, "
    SELECT
        SUM(result = 'ok')                                    AS ok,
        SUM(result = 'device_reuse')                          AS device_reuse,
        SUM(result = 'bad_room_code')                         AS bad_room_code,
        SUM(selfie_path IS NOT NULL AND selfie_path <> '')    AS selfies
    FROM attendance_audit_tbl
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    $scopeSql
", 'i' . $scopeType, array_merge([$days], $scopeParams));

if ($totals === null) {
    $ready  = false;
    $totals = [[]];
}

$t = $totals[0] ?? [];
$nOk      = (int) ($t['ok']            ?? 0);
$nReuse   = (int) ($t['device_reuse']  ?? 0);
$nBadCode = (int) ($t['bad_room_code'] ?? 0);
$nSelfies = (int) ($t['selfies']       ?? 0);

// ── Mga device na nagsilbi sa mahigit isang estudyante ───────
//
// Ito ang pinakamalapit na bagay sa isang sagot na maibibigay ng
// talaang ito. Ang isang device na may dalawang pangalan ay
// maaaring hiniram na telepono; ang may lima ay hindi na.
//
// Ang mga naharang ay kasama rito (result IN ok, device_reuse):
// ang nasa likod ng harang ay mismong ang sinusubukang gawin, at
// iyon ang gustong makita ng instruktor.
$devices = audit_query($conn, "
    SELECT device_id,
           MAX(fingerprint)                 AS fingerprint,
           MAX(ip)                          AS ip,
           MAX(user_agent)                  AS user_agent,
           COUNT(DISTINCT student_no)       AS students,
           SUM(result = 'ok')               AS saved,
           SUM(result = 'device_reuse')     AS blocked,
           MAX(created_at)                  AS last_seen,
           GROUP_CONCAT(DISTINCT student_no ORDER BY student_no SEPARATOR ', ') AS student_list
    FROM attendance_audit_tbl
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
      AND device_id IS NOT NULL
      AND result IN ('ok', 'device_reuse')
      $scopeSql
    GROUP BY device_id
    HAVING students > 1
    ORDER BY students DESC, last_seen DESC
    LIMIT 50
", 'i' . $scopeType, array_merge([$days], $scopeParams)) ?? [];

// ── Ang mga pangyayari ───────────────────────────────────────
if ($show === 'flagged') {
    $filterSql = " AND result IN ('device_reuse', 'bad_room_code') ";
} elseif ($show === 'selfies') {
    $filterSql = " AND selfie_path IS NOT NULL AND selfie_path <> '' ";
} else {
    $filterSql = '';
}

$events = audit_query($conn, "
    SELECT a.*, s.fullname
    FROM attendance_audit_tbl a
    LEFT JOIN students_tbl s ON s.student_no = a.student_no
    WHERE a.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
      $filterSql
      " . ($is_admin ? '' : ' AND a.instructor_id = ? ') . "
    ORDER BY a.id DESC
    LIMIT 200
", 'i' . $scopeType, array_merge([$days], $scopeParams)) ?? [];

/** Ang label at kulay ng bawat kahihinatnan. */
function result_chip(string $result): array
{
    switch ($result) {
        case 'ok':            return ['Saved',           'ok',      'bi-check-circle-fill'];
        case 'device_reuse':  return ['Same device',     'blocked', 'bi-phone-fill'];
        case 'bad_room_code': return ['Wrong code',      'blocked', 'bi-display'];
        case 'duplicate':     return ['Already in',      'muted',   'bi-arrow-repeat'];
        case 'not_enrolled':  return ['Not enrolled',    'muted',   'bi-person-dash'];
        default:              return [ucfirst($result),  'muted',   'bi-question-circle'];
    }
}

/**
 * Ang telepono, sa isang sulyap.
 *
 * Ang buong user agent ay isang talata na walang sinasabi sa taong
 * tumitingin sa isang talahanayan. Ang kailangan lamang niyang
 * malaman ay kung ang dalawang hilera ay iisang uri ng telepono.
 */
function device_label(?string $ua): string
{
    $ua = (string) $ua;
    if ($ua === '') return 'Unknown device';

    $os = 'Unknown';
    if (preg_match('/Android[ \/]?([\d.]+)?/i', $ua, $m))      $os = 'Android ' . ($m[1] ?? '');
    elseif (preg_match('/iPhone OS ([\d_]+)/i', $ua, $m))      $os = 'iPhone ' . str_replace('_', '.', $m[1]);
    elseif (stripos($ua, 'iPad') !== false)                    $os = 'iPad';
    elseif (stripos($ua, 'Windows') !== false)                 $os = 'Windows';
    elseif (stripos($ua, 'Mac OS X') !== false)                $os = 'Mac';
    elseif (stripos($ua, 'Linux') !== false)                   $os = 'Linux';

    $browser = 'Browser';
    if (stripos($ua, 'FBAV') !== false || stripos($ua, 'FB_IAB') !== false) $browser = 'Facebook';
    elseif (stripos($ua, 'Edg/') !== false)                                 $browser = 'Edge';
    elseif (stripos($ua, 'OPR/') !== false)                                 $browser = 'Opera';
    elseif (stripos($ua, 'Chrome') !== false)                               $browser = 'Chrome';
    elseif (stripos($ua, 'Firefox') !== false)                              $browser = 'Firefox';
    elseif (stripos($ua, 'Safari') !== false)                               $browser = 'Safari';

    return trim($os) . ' · ' . $browser;
}
?>
<!doctype html>
<html lang="en">

<head>
    <title>Attendance Integrity</title>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/attendance-integrity.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content ati-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="container-fluid px-3 px-md-4 py-3">

            <div class="ati-hero">
                <div class="ati-hero-icon"><i class="bi bi-shield-check"></i></div>
                <div class="ati-hero-text">
                    <h2>Attendance Integrity</h2>
                    <p>Which device each submission came from, and what was turned away.</p>
                </div>

                <div class="ati-range">
                    <?php foreach ([1 => 'Today', 7 => '7 days', 30 => '30 days'] as $d => $label): ?>
                        <a class="ati-range-btn <?= $days === $d ? 'is-on' : '' ?>"
                           href="?days=<?= $d ?>&show=<?= htmlspecialchars($show) ?>"><?= $label ?></a>
                    <?php endforeach; ?>
                </div>
            </div>

            <?php if (!$ready): ?>
                <div class="ati-empty">
                    <i class="bi bi-database-exclamation"></i>
                    <h5>The integrity log is not set up yet</h5>
                    <p>
                        Run <code>migrations/2026-09-09_add_attendance_integrity.sql</code> against the
                        database. Until then attendance keeps working exactly as before — nothing is
                        being blocked, and nothing is being recorded here.
                    </p>
                </div>
            <?php else: ?>

                <!-- ── Mga bilang ── -->
                <div class="ati-stats">
                    <div class="ati-stat">
                        <span class="ati-stat-label">Recorded</span>
                        <span class="ati-stat-figure"><?= number_format($nOk) ?></span>
                        <span class="ati-stat-note">submissions saved</span>
                    </div>
                    <div class="ati-stat <?= $nReuse > 0 ? 'is-alert' : '' ?>">
                        <span class="ati-stat-label">Same device</span>
                        <span class="ati-stat-figure"><?= number_format($nReuse) ?></span>
                        <span class="ati-stat-note">turned away as a second student</span>
                    </div>
                    <div class="ati-stat <?= $nBadCode > 0 ? 'is-alert' : '' ?>">
                        <span class="ati-stat-label">Wrong code</span>
                        <span class="ati-stat-figure"><?= number_format($nBadCode) ?></span>
                        <span class="ati-stat-note">room code did not match</span>
                    </div>
                    <div class="ati-stat">
                        <span class="ati-stat-label">Photo checks</span>
                        <span class="ati-stat-figure"><?= number_format($nSelfies) ?></span>
                        <span class="ati-stat-note">selfies captured</span>
                    </div>
                </div>

                <!-- ── Mga device na nagsilbi sa mahigit isang tao ── -->
                <div class="ati-card">
                    <div class="ati-card-head">
                        <h3><i class="bi bi-phone"></i> Devices used by more than one student</h3>
                        <span class="ati-count"><?= count($devices) ?></span>
                    </div>

                    <?php if (empty($devices)): ?>
                        <p class="ati-none">
                            <i class="bi bi-check2-circle"></i>
                            Every device in this period submitted for one student only.
                        </p>
                    <?php else: ?>
                        <p class="ati-lede">
                            One phone with two names on it may be a borrowed phone. One with five is
                            not. The count below includes attempts that were blocked — that is the
                            part worth reading.
                        </p>
                        <div class="table-responsive">
                            <table class="table ati-table">
                                <thead>
                                    <tr>
                                        <th>Device</th>
                                        <th>Students</th>
                                        <th>Saved</th>
                                        <th>Blocked</th>
                                        <th>Last seen</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($devices as $d): ?>
                                        <tr class="<?= (int) $d['students'] >= 3 ? 'is-hot' : '' ?>">
                                            <td>
                                                <div class="ati-device"><?= htmlspecialchars(device_label($d['user_agent'])) ?></div>
                                                <div class="ati-sub">
                                                    <?php /* Ang unang walong karakter lamang: sapat para
                                                            ihambing ang dalawang hilera, at hindi buong
                                                            cookie value na nakalatag sa screen. */ ?>
                                                    <code><?= htmlspecialchars(substr((string) $d['device_id'], 0, 8)) ?></code>
                                                    · <?= htmlspecialchars((string) $d['ip']) ?>
                                                </div>
                                            </td>
                                            <td>
                                                <span class="ati-pill"><?= (int) $d['students'] ?></span>
                                                <div class="ati-sub"><?= htmlspecialchars((string) $d['student_list']) ?></div>
                                            </td>
                                            <td><?= (int) $d['saved'] ?></td>
                                            <td><?= (int) $d['blocked'] ?></td>
                                            <td class="ati-when"><?= date('M j, g:i A', strtotime($d['last_seen'])) ?></td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php endif; ?>
                </div>

                <!-- ── Ang mga pangyayari ── -->
                <div class="ati-card">
                    <div class="ati-card-head">
                        <h3><i class="bi bi-list-ul"></i> Submissions</h3>
                        <div class="ati-tabs">
                            <?php foreach (['flagged' => 'Flagged', 'selfies' => 'Photo checks', 'all' => 'Everything'] as $key => $label): ?>
                                <a class="ati-tab <?= $show === $key ? 'is-on' : '' ?>"
                                   href="?days=<?= $days ?>&show=<?= $key ?>"><?= $label ?></a>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <?php if (empty($events)): ?>
                        <p class="ati-none">
                            <i class="bi bi-check2-circle"></i>
                            <?= $show === 'flagged'
                                ? 'Nothing was turned away in this period.'
                                : 'Nothing recorded in this period.' ?>
                        </p>
                    <?php else: ?>
                        <div class="table-responsive">
                            <table class="table ati-table">
                                <thead>
                                    <tr>
                                        <th>When</th>
                                        <th>Student</th>
                                        <th>Class</th>
                                        <th>Device</th>
                                        <th>Result</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($events as $e): ?>
                                        <?php [$chipText, $chipKind, $chipIcon] = result_chip($e['result']); ?>
                                        <tr>
                                            <td class="ati-when"><?= date('M j, g:i A', strtotime($e['created_at'])) ?></td>
                                            <td>
                                                <div class="ati-name"><?= htmlspecialchars($e['fullname'] ?? $e['student_no']) ?></div>
                                                <div class="ati-sub"><?= htmlspecialchars($e['student_no']) ?></div>
                                            </td>
                                            <td>
                                                <div><?= htmlspecialchars((string) $e['subject_name']) ?></div>
                                                <div class="ati-sub"><?= htmlspecialchars((string) $e['section']) ?></div>
                                            </td>
                                            <td>
                                                <div><?= htmlspecialchars(device_label($e['user_agent'])) ?></div>
                                                <div class="ati-sub">
                                                    <code><?= htmlspecialchars(substr((string) $e['device_id'], 0, 8)) ?></code>
                                                    · <?= htmlspecialchars((string) $e['ip']) ?>
                                                </div>
                                            </td>
                                            <td>
                                                <span class="ati-chip is-<?= $chipKind ?>">
                                                    <i class="bi <?= $chipIcon ?>"></i><?= $chipText ?>
                                                </span>
                                                <?php if (!empty($e['selfie_path'])): ?>
                                                    <a class="ati-shot" target="_blank"
                                                       href="../<?= htmlspecialchars($e['selfie_path']) ?>"
                                                       title="Open the photo taken at submission">
                                                        <img src="../<?= htmlspecialchars($e['selfie_path']) ?>"
                                                             alt="Photo taken when <?= htmlspecialchars($e['student_no']) ?> submitted" loading="lazy">
                                                    </a>
                                                <?php endif; ?>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>

                        <p class="ati-foot">
                            <i class="bi bi-clock-history"></i>
                            The log keeps the last 30 days. Older rows are removed automatically.
                        </p>
                    <?php endif; ?>
                </div>

            <?php endif; ?>
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
