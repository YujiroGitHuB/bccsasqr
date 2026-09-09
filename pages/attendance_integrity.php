<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";

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

const ATI_PER_PAGE   = 50;   // hilera kada pahina ng mga pangyayari
const ATI_DEVICE_CAP = 50;   // pinakamarami sa talahanayan ng device

// ── Ang mga salaan ───────────────────────────────────────────
//
// Lahat ay nasa URL at wala sa session: ang isang natuklasan dito ay
// isang bagay na ipinapadala mo sa kapwa guro o sa dean, at ang link
// na binubuksan nila ay dapat parehong tanawin ang ipinapakita.

// Ilang araw pabalik ang tinitingnan. Ang audit ay itinatago nang
// tatlumpung araw (INTEGRITY_AUDIT_DAYS), kaya walang saysay ang
// mas malayo pa rito.
$days = (int) ($_GET['days'] ?? 7);
if (!in_array($days, [1, 7, 30], true)) $days = 7;

// flagged  — device_reuse at not_enrolled, ang dalawang sinubukan
// all      — lahat
// ang iba  — isang tiyak na kahihinatnan, galing sa pagpindot ng tile
$show = $_GET['show'] ?? 'flagged';
if (!in_array($show, ['flagged', 'all', 'ok', 'device_reuse', 'duplicate', 'not_enrolled', 'lookup_limit'], true)) {
    $show = 'flagged';
}

// Ang short_code ng isang attendance link. Ang instruktor na may
// limang klase ay hindi naghahanap sa halo — isang klase ang
// tinitingnan niya sa isang pagkakataon.
$class = substr(trim((string) ($_GET['class'] ?? '')), 0, 10);

// Numero o pangalan ng estudyante.
$q = substr(trim((string) ($_GET['q'] ?? '')), 0, 60);

// Ang pagbaba mula sa isang device papunta sa mismong mga hilera
// nito. 32 hex na karakter ang buo, pero ang ipinapakita sa
// talahanayan ay ang unang walo — kaya tinatanggap ang alinman.
$device = (string) ($_GET['device'] ?? '');
if (!preg_match('/^[0-9a-f]{1,32}$/', $device)) $device = '';

$page = max(1, (int) ($_GET['page'] ?? 1));

/** Ang kasalukuyang tanawin bilang URL, may isa o dalawang binago. */
$filters = ['days' => $days, 'show' => $show, 'class' => $class, 'q' => $q, 'device' => $device];
$url = function (array $over = []) use ($filters): string {
    $next = array_merge($filters, $over);
    // Ang page ay hindi kailanman nadadala maliban kung sadyang
    // ibinigay: ang bagong salaan ay laging nagsisimula sa unang
    // pahina, kung hindi ay mauuwi ka sa blangkong pahina 4 ng isang
    // listahang may tatlo.
    $next = array_filter($next, static fn($v) => $v !== '' && $v !== null);
    return '?' . htmlspecialchars(http_build_query($next), ENT_QUOTES);
};

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

// ── Ang saklaw, itinatayo nang isang beses ───────────────────
//
// Isang WHERE na pinagsasaluhan ng LAHAT ng tanong sa ibaba: ang mga
// bilang sa itaas, ang mga device, ang bilang ng pahina at ang mga
// hilera mismo. Isang kalipunan, kaya hindi maaaring magsalungat ang
// tile at ang talahanayang nasa ilalim nito.
//
// Ang unang salaan ay hindi pinipili ng gumagamit: ang admin ay
// nakikita ang lahat, ang instruktor ay ang sarili niyang klase
// lamang. Kung makakalimutan ito ng isang tanong, makikita ng
// instruktor ang mga estudyante ng ibang guro.
$baseWhere  = ' a.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY) ';
$baseTypes  = 'i';
$baseParams = [$days];

if (!$is_admin) {
    $baseWhere .= ' AND a.instructor_id = ? ';
    $baseTypes .= 'i';
    $baseParams[] = $user_id;
}

if ($class !== '') {
    $baseWhere .= ' AND a.short_code = ? ';
    $baseTypes .= 's';
    $baseParams[] = $class;
}

if ($device !== '') {
    // LIKE at hindi '=': ang ipinapakita sa talahanayan ay ang unang
    // walong karakter, at iyon din ang dala ng link na pinindot.
    $baseWhere .= ' AND a.device_id LIKE ? ';
    $baseTypes .= 's';
    $baseParams[] = $device . '%';
}

if ($q !== '') {
    // EXISTS at hindi JOIN: ginagamit din ang salaang ito ng tanong sa
    // mga device, at doon ay may COUNT(DISTINCT student_no) na hindi
    // dapat maapektuhan ng anumang hilerang idinagdag ng isang join.
    $baseWhere .= ' AND (a.student_no LIKE ?
                         OR EXISTS (SELECT 1 FROM students_tbl sq
                                    WHERE sq.student_no = a.student_no
                                      AND sq.fullname LIKE ?)) ';
    $baseTypes .= 'ss';
    $baseParams[] = '%' . $q . '%';
    $baseParams[] = '%' . $q . '%';
}

// Ang salaan ng kahihinatnan ay HIWALAY sa base: ang mga tile sa
// itaas ay nagbibilang sa loob ng saklaw ngunit sa kabila ng
// kahihinatnan — kung hindi, ang pagpindot sa "Same device" ay
// gagawing 0 ang tatlong tile sa tabi nito.
$resultWhere  = '';
$resultTypes  = '';
$resultParams = [];

if ($show === 'flagged') {
    // Lima, at hindi ang dating isa. Ang pinagsasaluhan ng mga ito ay
    // hindi ang pagkabigo — ang pagkukusa: may nagtangkang gawin ang
    // isang bagay na hindi kanya. Ang sarado nang link at ang kulang
    // na larawan ay pagkabigo rin, pero pang-araw-araw na hadlang
    // iyon, at ang pagsasama sa kanila rito ay paglibing sa lima.
    $resultWhere = " AND a.result IN
        ('device_reuse', 'not_enrolled', 'lookup_limit', 'no_student', 'bad_link') ";
} elseif ($show !== 'all') {
    $resultWhere  = ' AND a.result = ? ';
    $resultTypes  = 's';
    $resultParams = [$show];
}

$ready = true;

// ── Mga bilang sa itaas ──────────────────────────────────────
$totals = audit_query($conn, "
    SELECT
        SUM(a.result = 'ok')           AS ok,
        SUM(a.result = 'device_reuse') AS device_reuse,
        SUM(a.result = 'not_enrolled') AS not_enrolled,
        SUM(a.result = 'lookup_limit') AS lookup_limit,
        SUM(a.result = 'duplicate')    AS duplicate
    FROM attendance_audit_tbl a
    WHERE $baseWhere
", $baseTypes, $baseParams);

if ($totals === null) {
    $ready  = false;
    $totals = [[]];
}

$t = $totals[0] ?? [];
$nOk    = (int) ($t['ok']           ?? 0);
$nReuse = (int) ($t['device_reuse'] ?? 0);
$nUnenr = (int) ($t['not_enrolled'] ?? 0);
$nHunt  = (int) ($t['lookup_limit'] ?? 0);
$nDup   = (int) ($t['duplicate']    ?? 0);

// ── Naka-ON pa ba ang harang? ────────────────────────────────
//
// Kung wala ito, ang pahina ay pareho ang hitsura kung tumatakbo ang
// device binding at kung pinatay ito kaninang umaga: nariyan pa rin
// ang "6 turned away" mula sa nakaraan, at walang nagsasabing wala
// nang humaharang ngayon. Ito ang pinakamadaling maling mabasa sa
// buong pahina.
$bindingOn = integrity_setting($conn, 'device_binding', '1') === '1';

// ── Ang mga klase sa dropdown ────────────────────────────────
//
// Hindi apektado ng $class mismo, kung hindi ay mawawalan ng laman
// ang dropdown pagkatapos ng unang pagpili.
$classWhere  = ' a.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY) ';
$classTypes  = 'i';
$classParams = [$days];

if (!$is_admin) {
    $classWhere .= ' AND a.instructor_id = ? ';
    $classTypes .= 'i';
    $classParams[] = $user_id;
}

$classes = audit_query($conn, "
    SELECT a.short_code,
           MAX(a.subject_name) AS subject_name,
           MAX(a.section)      AS section,
           COUNT(*)            AS n
    FROM attendance_audit_tbl a
    WHERE $classWhere
    GROUP BY a.short_code
    ORDER BY MAX(a.created_at) DESC
    LIMIT 60
", $classTypes, $classParams) ?? [];

// ── Mga device na nagsilbi sa mahigit isang estudyante ───────
//
// Ito ang pinakamalapit na bagay sa isang sagot na maibibigay ng
// talaang ito. Ang isang device na may dalawang pangalan ay
// maaaring hiniram na telepono; ang may lima ay hindi na.
//
// Ang mga naharang ay kasama rito (result IN ok, device_reuse):
// ang nasa likod ng harang ay mismong ang sinusubukang gawin, at
// iyon ang gustong makita ng instruktor.
$deviceWhere = " $baseWhere AND a.device_id IS NOT NULL AND a.result IN ('ok', 'device_reuse') ";

$devices = audit_query($conn, "
    SELECT a.device_id,
           MAX(a.fingerprint)             AS fingerprint,
           MAX(a.ip)                      AS ip,
           MAX(a.user_agent)              AS user_agent,
           COUNT(DISTINCT a.student_no)   AS students,
           SUM(a.result = 'ok')           AS saved,
           SUM(a.result = 'device_reuse') AS blocked,
           MAX(a.created_at)              AS last_seen,
           GROUP_CONCAT(DISTINCT a.student_no ORDER BY a.student_no SEPARATOR ', ') AS student_list
    FROM attendance_audit_tbl a
    WHERE $deviceWhere
    GROUP BY a.device_id
    HAVING students > 1
    ORDER BY students DESC, last_seen DESC
    LIMIT " . ATI_DEVICE_CAP . "
", $baseTypes, $baseParams) ?? [];

// Ang tunay na bilang, at hindi count($devices): ang "50" sa isang
// talahanayang pinutol sa 50 ay isang kasinungalingang mukhang
// katotohanan.
$deviceTotalRow = audit_query($conn, "
    SELECT COUNT(*) AS n FROM (
        SELECT a.device_id
        FROM attendance_audit_tbl a
        WHERE $deviceWhere
        GROUP BY a.device_id
        HAVING COUNT(DISTINCT a.student_no) > 1
    ) t
", $baseTypes, $baseParams);
$deviceTotal = (int) ($deviceTotalRow[0]['n'] ?? count($devices));

// ── Isang telepono, maraming cookie ──────────────────────────
//
// Ang device_id ay cookie, at ang cookie ay kayang burahin — iyon
// ang inaming hangganan ng buong tampok. Ang fingerprint ang natira
// kapag nangyari iyon: user agent, wika, laki ng screen, time zone.
// Naitatala ito mula pa noong unang araw at wala pang bumabasa.
//
// MAHINA ito, at sinasadya: ang dalawang bagong teleponong
// magkapareho ang modelo ay magkapareho rin ang bawat sangkap nito.
// Kaya HINDI ito humaharang at hindi ito nagsasabing may nangyaring
// mali — ang ipinapakita ay ang hugis, at ang ORAS ang nagsasabi ng
// pagkakaiba. Ang dalawang kaklaseng may parehong telepono ay
// magsusumite nang magkalayo ang oras; ang isang teleponong
// binubura ang cookie sa pagitan ng bawat pangalan ay tapos na sa
// loob ng ilang minuto.
$prints = audit_query($conn, "
    SELECT a.fingerprint,
           COUNT(DISTINCT a.device_id)  AS devices,
           COUNT(DISTINCT a.student_no) AS students,
           MAX(a.user_agent)            AS user_agent,
           MAX(a.ip)                    AS ip,
           MAX(a.created_at)            AS last_seen,
           TIMESTAMPDIFF(MINUTE, MIN(a.created_at), MAX(a.created_at)) AS span_min,
           GROUP_CONCAT(DISTINCT a.student_no ORDER BY a.student_no SEPARATOR ', ') AS student_list
    FROM attendance_audit_tbl a
    WHERE $baseWhere
      AND a.fingerprint IS NOT NULL
      AND a.fingerprint <> ''
      AND a.device_id IS NOT NULL
      AND a.result IN ('ok', 'device_reuse')
    GROUP BY a.fingerprint
    HAVING devices > 1 AND students > 1
    ORDER BY span_min ASC, devices DESC
    LIMIT 25
", $baseTypes, $baseParams) ?? [];

// ── May pagsusuri na ba ang talahanayan? ─────────────────────
//
// Ang tatlong column ay dumarating kasama ng
// migrations/2026-09-10_add_audit_review.sql. Kapag hindi pa
// napapatakbo, ang pahina ay gumagana pa rin — nawawala lamang ang
// isang hanay. Kaparehong tuntunin ng buong pahina: ang tampok na
// hindi pa handa ay hindi dapat maging basag na pahina.
$hasReview = integrity_has_column($conn, 'reviewed_at');

// ── Ang mga pangyayari ───────────────────────────────────────
$eventTypes  = $baseTypes . $resultTypes;
$eventParams = array_merge($baseParams, $resultParams);

$eventTotalRow = audit_query($conn, "
    SELECT COUNT(*) AS n
    FROM attendance_audit_tbl a
    WHERE $baseWhere $resultWhere
", $eventTypes, $eventParams);
$eventTotal = (int) ($eventTotalRow[0]['n'] ?? 0);

$lastPage = max(1, (int) ceil($eventTotal / ATI_PER_PAGE));
if ($page > $lastPage) $page = $lastPage;
$offset = ($page - 1) * ATI_PER_PAGE;

// a.* ay dala na ang reviewed_at at note kapag naroon ang mga ito;
// ang pangalan lamang ng sumuri ang nangangailangan ng join, at
// idinadagdag lamang kapag may column na hahanapin.
$events = audit_query($conn, "
    SELECT a.*, s.fullname
           " . ($hasReview ? ', ru.name AS reviewed_by_name' : '') . "
    FROM attendance_audit_tbl a
    LEFT JOIN students_tbl s ON s.student_no = a.student_no
    " . ($hasReview ? ' LEFT JOIN users ru ON ru.id = a.reviewed_by ' : '') . "
    WHERE $baseWhere $resultWhere
    ORDER BY a.id DESC
    LIMIT ? OFFSET ?
", $eventTypes . 'ii', array_merge($eventParams, [ATI_PER_PAGE, $offset])) ?? [];

/** Ang label at kulay ng bawat kahihinatnan. */
function result_chip(string $result): array
{
    switch ($result) {
        // Ang pumasa.
        case 'ok':            return ['Saved',            'ok',      'bi-check-circle-fill'];

        // Ang may pagkukusa. Pula: tingnan mo ito.
        case 'device_reuse':  return ['Same device',      'blocked', 'bi-phone-fill'];
        case 'lookup_limit':  return ['Lookup limit',     'blocked', 'bi-binoculars-fill'];

        // Ang kayang maging pagkakamali sa pagtipa, at kayang hindi.
        case 'not_enrolled':  return ['Not enrolled',     'warn',    'bi-person-dash'];
        case 'no_student':    return ['No such number',   'warn',    'bi-question-circle'];
        case 'bad_link':      return ['Link not valid',   'warn',    'bi-link-45deg'];
        case 'save_failed':   return ['Save failed',      'warn',    'bi-exclamation-triangle'];

        // Ang pang-araw-araw na hadlang. Walang kulay: hindi ito balita.
        case 'duplicate':     return ['Already in',       'muted',   'bi-arrow-repeat'];
        case 'link_expired':  return ['Link had closed',  'muted',   'bi-clock-history'];
        case 'link_off':      return ['Link switched off', 'muted',  'bi-toggle-off'];
        case 'form_locked':   return ['Form locked',      'muted',   'bi-lock-fill'];
        case 'photo_missing': return ['No photo yet',     'muted',   'bi-image'];

        default:              return [ucfirst($result),   'muted',   'bi-question-circle'];
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

// Ang pangalan ng klaseng pinili, para sa chip ng salaan.
$classLabel = $class;
foreach ($classes as $c) {
    if ($c['short_code'] === $class) {
        $classLabel = trim(trim((string) $c['subject_name']) . ' · ' . trim((string) $c['section']), ' ·') ?: $class;
        break;
    }
}

/** Ang mga salaang aktibo ngayon, bilang matatanggal na chip. */
$activeChips = [];
if ($class !== '')  $activeChips[] = ['bi-journal-text', $classLabel,         ['class'  => '']];
if ($q !== '')      $activeChips[] = ['bi-search',       '"' . $q . '"',      ['q'      => '']];
if ($device !== '') $activeChips[] = ['bi-phone',        'Device ' . $device, ['device' => '']];
if (!in_array($show, ['flagged', 'all'], true)) {
    $activeChips[] = ['bi-funnel', result_chip($show)[0], ['show' => 'all']];
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
                    <?php /* Sinasabi kung ANO ang saklaw. Ang link lamang ang dumadaan
                            dito: ang QR scanner (crud/save_attendance.php) at ang import
                            (crud/upload_attendance.php) ay sumusulat sa attendance_tbl
                            nang hindi nagdaraan sa talaang ito, at pareho silang hawak ng
                            taong naka-log in. Ang "Recorded 24" na binabasa bilang bilang
                            ng lahat ng pagpasok ay isang maling bilang. */ ?>
                    <p>Every submission through the <strong>attendance link</strong> — the device it
                       came from, and what was turned away. Scans and imports are not listed here.</p>
                </div>

                <div class="ati-range">
                    <?php foreach ([1 => 'Today', 7 => '7 days', 30 => '30 days'] as $d => $label): ?>
                        <a class="ati-range-btn <?= $days === $d ? 'is-on' : '' ?>"
                           href="<?= $url(['days' => $d]) ?>"><?= $label ?></a>
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
                    <p class="ati-empty-cta">
                        <a href="../pages/integrity_check.php">
                            <i class="bi bi-clipboard-pulse"></i> Run the setup check
                        </a>
                    </p>
                </div>
            <?php else: ?>

                <?php if (!$bindingOn): ?>
                    <!-- Ang pahinang ito ay nagpapakita ng nakaraan. Kapag patay ang
                         harang, ang nakaraang iyon ay hindi na ang kasalukuyan. -->
                    <div class="ati-warn">
                        <i class="bi bi-shield-slash"></i>
                        <div>
                            <strong>One Device, One Student is switched off.</strong>
                            Nothing below is being blocked right now — one phone can record
                            attendance for as many students as it likes. The log keeps running, so
                            submissions are still listed here.
                            <a href="../pages/settings.php">Turn it back on</a>
                        </div>
                    </div>
                <?php endif; ?>

                <!-- ── Mga bilang ──
                     Bawat tile ay isang link papunta sa sarili nitong mga hilera. Ang
                     "6 turned away" na hindi mapipindot ay isang bilang na kailangan
                     mo pang hanapin sa listahan sa ibaba. -->
                <div class="ati-stats">
                    <a class="ati-stat <?= $show === 'ok' ? 'is-picked' : '' ?>"
                       href="<?= $url(['show' => 'ok']) ?>">
                        <span class="ati-stat-label">Recorded</span>
                        <span class="ati-stat-figure"><?= number_format($nOk) ?></span>
                        <span class="ati-stat-note">saved from the link</span>
                    </a>
                    <a class="ati-stat <?= $nReuse > 0 ? 'is-alert' : '' ?> <?= $show === 'device_reuse' ? 'is-picked' : '' ?>"
                       href="<?= $url(['show' => 'device_reuse']) ?>">
                        <span class="ati-stat-label">Same device</span>
                        <span class="ati-stat-figure"><?= number_format($nReuse) ?></span>
                        <span class="ati-stat-note">turned away as a second student</span>
                    </a>
                    <a class="ati-stat <?= $nUnenr > 0 ? 'is-warn' : '' ?> <?= $show === 'not_enrolled' ? 'is-picked' : '' ?>"
                       href="<?= $url(['show' => 'not_enrolled']) ?>">
                        <span class="ati-stat-label">Not enrolled</span>
                        <span class="ati-stat-figure"><?= number_format($nUnenr) ?></span>
                        <span class="ati-stat-note">a number that is not in the class</span>
                    </a>
                    <a class="ati-stat <?= $nHunt > 0 ? 'is-alert' : '' ?> <?= $show === 'lookup_limit' ? 'is-picked' : '' ?>"
                       href="<?= $url(['show' => 'lookup_limit']) ?>">
                        <span class="ati-stat-label">Looking around</span>
                        <span class="ati-stat-figure"><?= number_format($nHunt) ?></span>
                        <span class="ati-stat-note">stopped for too many lookups</span>
                    </a>
                    <a class="ati-stat <?= $show === 'duplicate' ? 'is-picked' : '' ?>"
                       href="<?= $url(['show' => 'duplicate']) ?>">
                        <span class="ati-stat-label">Repeats</span>
                        <span class="ati-stat-figure"><?= number_format($nDup) ?></span>
                        <span class="ati-stat-note">already recorded today</span>
                    </a>
                </div>

                <!-- ── Ang mga salaan ── -->
                <form class="ati-filters" method="get">
                    <input type="hidden" name="days" value="<?= $days ?>">
                    <input type="hidden" name="show" value="<?= htmlspecialchars($show) ?>">
                    <?php if ($device !== ''): ?>
                        <input type="hidden" name="device" value="<?= htmlspecialchars($device) ?>">
                    <?php endif; ?>

                    <label class="ati-field">
                        <i class="bi bi-journal-text"></i>
                        <select name="class">
                            <option value="">All classes</option>
                            <?php foreach ($classes as $c): ?>
                                <?php $label = trim(trim((string) $c['subject_name']) . ' · ' . trim((string) $c['section']), ' ·'); ?>
                                <option value="<?= htmlspecialchars($c['short_code']) ?>"
                                    <?= $c['short_code'] === $class ? 'selected' : '' ?>>
                                    <?= htmlspecialchars($label ?: $c['short_code']) ?> (<?= (int) $c['n'] ?>)
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>

                    <label class="ati-field ati-field-grow">
                        <i class="bi bi-search"></i>
                        <input type="search" name="q" value="<?= htmlspecialchars($q) ?>"
                               placeholder="Student number or name — 025-002, Angeles">
                    </label>

                    <button type="submit" class="ati-go">Apply</button>
                    <?php if ($activeChips): ?>
                        <a class="ati-clear"
                           href="<?= $url(['class' => '', 'q' => '', 'device' => '', 'show' => 'flagged']) ?>">Clear</a>
                    <?php endif; ?>

                    <?php /* Kaparehong salaan, walang LIMIT. Ang dinadala mo sa ibang
                            tao ay ang tanawing tinitingnan mo ngayon — at hindi ang
                            unang limampu nito. */ ?>
                    <a class="ati-export" href="../exports/export_integrity_csv.php<?= $url() ?>">
                        <i class="bi bi-filetype-csv"></i> Export
                    </a>
                </form>

                <?php if ($activeChips): ?>
                    <div class="ati-chips">
                        <?php foreach ($activeChips as [$chipIcon, $chipLabel, $off]): ?>
                            <a class="ati-fchip" href="<?= $url($off) ?>">
                                <i class="bi <?= $chipIcon ?>"></i><?= htmlspecialchars($chipLabel) ?>
                                <i class="bi bi-x-lg"></i>
                            </a>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>

                <!-- ── Mga device na nagsilbi sa mahigit isang tao ── -->
                <div class="ati-card">
                    <div class="ati-card-head">
                        <h3><i class="bi bi-phone"></i> Devices used by more than one student</h3>
                        <span class="ati-count"><?= number_format($deviceTotal) ?></span>
                    </div>

                    <?php if (empty($devices)): ?>
                        <p class="ati-none">
                            <i class="bi bi-check2-circle"></i>
                            Every device in this view submitted for one student only.
                        </p>
                    <?php else: ?>
                        <p class="ati-lede">
                            One phone with two names on it may be a borrowed phone. One with five is
                            not. The count below includes attempts that were blocked — that is the
                            part worth reading. Open a row to see only that phone's submissions.
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
                                        <th></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($devices as $d): ?>
                                        <?php /* Ang unang walong karakter lamang: sapat para ihambing
                                                ang dalawang hilera, at hindi buong cookie value na
                                                nakalatag sa screen. Ito rin ang dala ng link. */ ?>
                                        <?php $short = substr((string) $d['device_id'], 0, 8); ?>
                                        <tr class="<?= (int) $d['students'] >= 3 ? 'is-hot' : '' ?>">
                                            <td>
                                                <div class="ati-device"><?= htmlspecialchars(device_label($d['user_agent'])) ?></div>
                                                <div class="ati-sub">
                                                    <code><?= htmlspecialchars($short) ?></code>
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
                                            <td class="text-end">
                                                <a class="ati-open" href="<?= $url(['device' => $short, 'show' => 'all']) ?>">
                                                    Open <i class="bi bi-arrow-right-short"></i>
                                                </a>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>

                        <?php if ($deviceTotal > count($devices)): ?>
                            <p class="ati-foot">
                                <i class="bi bi-three-dots"></i>
                                Showing the <?= count($devices) ?> most-shared of <?= number_format($deviceTotal) ?>.
                                Narrow the class or the date range to see the rest.
                            </p>
                        <?php endif; ?>
                    <?php endif; ?>
                </div>

                <!-- ── Isang telepono, maraming cookie ── -->
                <?php if (!empty($prints)): ?>
                    <div class="ati-card">
                        <div class="ati-card-head">
                            <h3><i class="bi bi-fingerprint"></i> Same phone signature, different device</h3>
                            <span class="ati-count"><?= count($prints) ?></span>
                        </div>

                        <p class="ati-lede">
                            The device check works off a cookie, and a cookie can be cleared. This
                            groups by what stays the same when it is — the phone model, screen,
                            language and time zone. <strong>Two classmates with the same model of
                            phone look identical here</strong>, so this is not proof of anything.
                            Read the <em>Within</em> column: submissions spread across a day are
                            ordinary, several in a few minutes are one person clearing a cookie.
                        </p>

                        <div class="table-responsive">
                            <table class="table ati-table">
                                <thead>
                                    <tr>
                                        <th>Phone signature</th>
                                        <th>Devices</th>
                                        <th>Students</th>
                                        <th>Within</th>
                                        <th>Last seen</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($prints as $p): ?>
                                        <?php
                                        // Mainit lamang kapag masikip ang oras AT marami ang
                                        // device. Alinman sa dalawa nang mag-isa ay ordinaryo.
                                        $span = (int) $p['span_min'];
                                        $hot  = ($span <= 15 && (int) $p['devices'] >= 3);
                                        ?>
                                        <tr class="<?= $hot ? 'is-hot' : '' ?>">
                                            <td>
                                                <div class="ati-device"><?= htmlspecialchars(device_label($p['user_agent'])) ?></div>
                                                <div class="ati-sub">
                                                    <code><?= htmlspecialchars((string) $p['fingerprint']) ?></code>
                                                    · <?= htmlspecialchars((string) $p['ip']) ?>
                                                </div>
                                            </td>
                                            <td><span class="ati-pill"><?= (int) $p['devices'] ?></span></td>
                                            <td>
                                                <span class="ati-pill"><?= (int) $p['students'] ?></span>
                                                <div class="ati-sub"><?= htmlspecialchars((string) $p['student_list']) ?></div>
                                            </td>
                                            <td class="ati-when">
                                                <?php if ($span < 60): ?>
                                                    <?= $span ?> min
                                                <?php elseif ($span < 1440): ?>
                                                    <?= round($span / 60) ?> hr
                                                <?php else: ?>
                                                    <?= round($span / 1440) ?> d
                                                <?php endif; ?>
                                            </td>
                                            <td class="ati-when"><?= date('M j, g:i A', strtotime($p['last_seen'])) ?></td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                <?php endif; ?>

                <!-- ── Ang mga pangyayari ── -->
                <div class="ati-card">
                    <div class="ati-card-head">
                        <h3><i class="bi bi-list-ul"></i> Submissions</h3>
                        <span class="ati-count"><?= number_format($eventTotal) ?></span>
                        <div class="ati-tabs">
                            <?php foreach (['flagged' => 'Flagged', 'all' => 'Everything'] as $key => $label): ?>
                                <a class="ati-tab <?= $show === $key ? 'is-on' : '' ?>"
                                   href="<?= $url(['show' => $key]) ?>"><?= $label ?></a>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <?php if (empty($events)): ?>
                        <p class="ati-none">
                            <i class="bi bi-check2-circle"></i>
                            <?= $show === 'flagged'
                                ? 'Nothing was turned away in this view.'
                                : 'Nothing recorded in this view.' ?>
                        </p>
                    <?php else: ?>
                        <?php if ($show === 'flagged'): ?>
                            <p class="ati-lede">
                                Someone meant to do this: a phone that had already signed in a
                                classmate, a number that is not on the class list or not in the
                                school at all, a link code that does not exist, and anyone stopped
                                for working through too many numbers at once. Everything else —
                                a closed link, a missing photo, a repeat — is under
                                <em>Everything</em>.
                            </p>
                        <?php endif; ?>
                        <div class="table-responsive">
                            <table class="table ati-table">
                                <thead>
                                    <tr>
                                        <th>When</th>
                                        <th>Student</th>
                                        <th>Class</th>
                                        <th>Device</th>
                                        <th>Result</th>
                                        <?php if ($hasReview): ?><th>Reviewed</th><?php endif; ?>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($events as $e): ?>
                                        <?php [$chipText, $chipKind, $chipIcon] = result_chip($e['result']); ?>
                                        <?php $short = substr((string) $e['device_id'], 0, 8); ?>
                                        <tr>
                                            <td class="ati-when"><?= date('M j, g:i A', strtotime($e['created_at'])) ?></td>
                                            <td>
                                                <div class="ati-name"><?= htmlspecialchars($e['fullname'] ?? $e['student_no']) ?></div>
                                                <div class="ati-sub">
                                                    <a href="<?= $url(['q' => $e['student_no'], 'show' => 'all', 'device' => '']) ?>"><?= htmlspecialchars($e['student_no']) ?></a>
                                                </div>
                                            </td>
                                            <td>
                                                <div><?= htmlspecialchars((string) $e['subject_name']) ?></div>
                                                <div class="ati-sub"><?= htmlspecialchars((string) $e['section']) ?></div>
                                            </td>
                                            <td>
                                                <div><?= htmlspecialchars(device_label($e['user_agent'])) ?></div>
                                                <div class="ati-sub">
                                                    <?php if ($short !== ''): ?>
                                                        <a href="<?= $url(['device' => $short, 'show' => 'all']) ?>"><code><?= htmlspecialchars($short) ?></code></a>
                                                        ·
                                                    <?php endif; ?>
                                                    <?= htmlspecialchars((string) $e['ip']) ?>
                                                </div>
                                            </td>
                                            <td>
                                                <span class="ati-chip is-<?= $chipKind ?>">
                                                    <i class="bi <?= $chipIcon ?>"></i><?= $chipText ?>
                                                </span>
                                            </td>

                                            <?php if ($hasReview): ?>
                                                <?php /* Ang cell na ito ay muling iginuguhit ng
                                                        assets/js/integrityReview.js pagkatapos ng
                                                        bawat pindot — magkatugma dapat ang hugis
                                                        nito at ang revRender() doon. */ ?>
                                                <td class="ati-review" data-id="<?= (int) $e['id'] ?>">
                                                    <?php if (!empty($e['reviewed_at'])): ?>
                                                        <div class="ati-rev-done">
                                                            <span class="ati-rev-mark"
                                                                  title="Reviewed by <?= htmlspecialchars((string) ($e['reviewed_by_name'] ?? 'someone')) ?>">
                                                                <i class="bi bi-check-circle-fill"></i><?= date('M j, g:i A', strtotime($e['reviewed_at'])) ?>
                                                            </span>
                                                            <?php if (!empty($e['note'])): ?>
                                                                <span class="ati-rev-note"><?= htmlspecialchars((string) $e['note']) ?></span>
                                                            <?php endif; ?>
                                                            <button type="button" class="ati-rev-undo"
                                                                    data-act="undo" data-id="<?= (int) $e['id'] ?>">Undo</button>
                                                        </div>
                                                    <?php else: ?>
                                                        <button type="button" class="ati-rev"
                                                                data-act="do" data-id="<?= (int) $e['id'] ?>">
                                                            <i class="bi bi-check2"></i> Review
                                                        </button>
                                                    <?php endif; ?>
                                                </td>
                                            <?php endif; ?>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>

                        <div class="ati-pager">
                            <span class="ati-pager-count">
                                Showing <?= number_format($offset + 1) ?>–<?= number_format($offset + count($events)) ?>
                                of <?= number_format($eventTotal) ?>
                            </span>

                            <?php if ($lastPage > 1): ?>
                                <div class="ati-pager-links">
                                    <?php if ($page > 1): ?>
                                        <a href="<?= $url(['page' => $page - 1]) ?>"><i class="bi bi-chevron-left"></i> Newer</a>
                                    <?php else: ?>
                                        <span class="is-off"><i class="bi bi-chevron-left"></i> Newer</span>
                                    <?php endif; ?>

                                    <span class="ati-pager-at">Page <?= $page ?> of <?= $lastPage ?></span>

                                    <?php if ($page < $lastPage): ?>
                                        <a href="<?= $url(['page' => $page + 1]) ?>">Older <i class="bi bi-chevron-right"></i></a>
                                    <?php else: ?>
                                        <span class="is-off">Older <i class="bi bi-chevron-right"></i></span>
                                    <?php endif; ?>
                                </div>
                            <?php endif; ?>
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
    <?php if ($ready && $hasReview): ?>
        <script src="<?= asset('../assets/js/integrityReview.js') ?>"></script>
    <?php endif; ?>
</body>

</html>
