<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/security_log.php";

// Its own key rather than db.monitor: this page shows IP addresses
// and the emails people tried to sign in as. Nobody gets it by
// default — admins pass can() regardless.
requirePermission('security.monitor');

const SEC_PER_PAGE = 50;

// ── Filters ──────────────────────────────────────────────────
// All in the URL, like the Integrity page, so a view can be sent
// to someone as a link.
$days = (int) ($_GET['days'] ?? 7);
if (!in_array($days, [1, 7, 30], true)) $days = 7;

$sev = (string) ($_GET['sev'] ?? 'all');
if (!in_array($sev, ['all', 'high', 'medium', 'low'], true)) $sev = 'all';

// A tile counts several event kinds at once, so it filters by the
// same group — "Failed sign-ins 12" has to open all twelve.
const SEC_EVENT_GROUPS = [
    'signin' => ['Every failed sign-in', 'bi-box-arrow-in-right', ['login_failed', 'login_no_user', 'login_disabled', 'brute_force']],
    'denied' => ['Every blocked request', 'bi-slash-circle',      ['access_denied', 'no_session']],
];

$event = (string) ($_GET['event'] ?? '');
if (!isset(SECURITY_EVENTS[$event]) && !isset(SEC_EVENT_GROUPS[$event])) $event = '';

$ip = trim((string) ($_GET['ip'] ?? ''));
if ($ip !== '' && !filter_var($ip, FILTER_VALIDATE_IP)) $ip = '';

$page = max(1, (int) ($_GET['page'] ?? 1));

$filters = ['days' => $days, 'sev' => $sev, 'event' => $event, 'ip' => $ip];
$url = function (array $over = []) use ($filters): string {
    $next = array_merge($filters, $over);
    $next = array_filter($next, static fn($v) => $v !== '' && $v !== null && $v !== 'all');
    return '?' . htmlspecialchars(http_build_query($next), ENT_QUOTES);
};

/** One query, or null when the table is not there yet. */
function sec_query(mysqli $conn, string $sql, string $types, array $params): ?array
{
    try {
        $stmt = $conn->prepare($sql);
        if ($types !== '') $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        return $rows;
    } catch (Throwable $e) {
        error_log('security_monitor: ' . $e->getMessage());
        return null;
    }
}

/** OS · browser from a user agent, or the tool's own name. */
function sec_ua_label(?string $ua): string
{
    $ua = (string) $ua;
    if ($ua === '') return 'No user agent';

    // A script is more telling than a phone model, so it wins.
    if (preg_match('/\b(curl|wget|python-requests|python|go-http-client|okhttp|java|postman|insomnia|sqlmap|nikto|nmap|nuclei|httpie)\b/i', $ua, $m)) {
        return 'Script · ' . $m[1];
    }

    $os = 'Unknown';
    if (preg_match('/Android[ \/]?([\d.]+)?/i', $ua, $m)) $os = 'Android ' . ($m[1] ?? '');
    elseif (preg_match('/iPhone OS ([\d_]+)/i', $ua, $m)) $os = 'iPhone ' . str_replace('_', '.', $m[1]);
    elseif (stripos($ua, 'iPad') !== false)               $os = 'iPad';
    elseif (stripos($ua, 'Windows') !== false)            $os = 'Windows';
    elseif (stripos($ua, 'Mac OS X') !== false)           $os = 'Mac';
    elseif (stripos($ua, 'Linux') !== false)              $os = 'Linux';

    $browser = 'Browser';
    if (stripos($ua, 'Edg/') !== false)         $browser = 'Edge';
    elseif (stripos($ua, 'OPR/') !== false)     $browser = 'Opera';
    elseif (stripos($ua, 'Chrome') !== false)   $browser = 'Chrome';
    elseif (stripos($ua, 'Firefox') !== false)  $browser = 'Firefox';
    elseif (stripos($ua, 'Safari') !== false)   $browser = 'Safari';

    return trim($os) . ' · ' . $browser;
}

/** Severity → the Integrity page's chip colours. */
function sec_chip_kind(string $severity): string
{
    return ['high' => 'blocked', 'medium' => 'warn'][$severity] ?? 'muted';
}

// The page is often the first thing to touch the table, before any
// attack has been logged — create it so the page opens empty rather
// than broken.
$ready = security_install($conn);

// ── Scope shared by every query ──────────────────────────────
$baseWhere  = ' e.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY) ';
$baseTypes  = 'i';
$baseParams = [$days];
if ($ip !== '') {
    $baseWhere   .= ' AND e.ip = ? ';
    $baseTypes   .= 's';
    $baseParams[] = $ip;
}

$listWhere  = $baseWhere;
$listTypes  = $baseTypes;
$listParams = $baseParams;
if ($sev !== 'all') {
    $listWhere   .= ' AND e.severity = ? ';
    $listTypes   .= 's';
    $listParams[] = $sev;
}
if (isset(SEC_EVENT_GROUPS[$event])) {
    $kinds        = SEC_EVENT_GROUPS[$event][2];
    $listWhere   .= ' AND e.event IN (' . implode(',', array_fill(0, count($kinds), '?')) . ') ';
    $listTypes   .= str_repeat('s', count($kinds));
    $listParams   = array_merge($listParams, $kinds);
} elseif ($event !== '') {
    $listWhere   .= ' AND e.event = ? ';
    $listTypes   .= 's';
    $listParams[] = $event;
}

// ── Counts ───────────────────────────────────────────────────
$t = (sec_query($conn, "
    SELECT COUNT(*)                                  AS total,
           SUM(e.severity = 'high')                  AS high,
           SUM(e.event IN ('login_failed', 'login_no_user', 'login_disabled')) AS signins,
           SUM(e.event = 'brute_force')              AS guessing,
           SUM(e.event = 'probe')                    AS probes,
           SUM(e.event IN ('access_denied', 'no_session')) AS denied,
           COUNT(DISTINCT e.ip)                      AS sources
    FROM security_events_tbl e
    WHERE $baseWhere
", $baseTypes, $baseParams) ?? [[]])[0];

$nTotal    = (int) ($t['total']    ?? 0);
$nHigh     = (int) ($t['high']     ?? 0);
$nSignins  = (int) ($t['signins']  ?? 0);
$nGuessing = (int) ($t['guessing'] ?? 0);
$nProbes   = (int) ($t['probes']   ?? 0);
$nDenied   = (int) ($t['denied']   ?? 0);
$nSources  = (int) ($t['sources']  ?? 0);

// Anything high in the last 24 hours gets a strip at the top, whatever
// range is being viewed — "30 days" should not bury this morning.
$recentHigh = (int) ((sec_query($conn, "
    SELECT COUNT(*) AS n FROM security_events_tbl
    WHERE severity = 'high' AND created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
", '', []) ?? [['n' => 0]])[0]['n'] ?? 0);

// ── Where it is coming from ──────────────────────────────────
$sources = $ip !== '' ? [] : (sec_query($conn, "
    SELECT e.ip,
           COUNT(*)                 AS n,
           SUM(e.severity = 'high') AS high,
           COUNT(DISTINCT e.event)  AS kinds,
           GROUP_CONCAT(DISTINCT e.event ORDER BY e.event SEPARATOR ',') AS events,
           GROUP_CONCAT(DISTINCT e.identifier ORDER BY e.identifier SEPARATOR ', ') AS targets,
           MAX(e.user_agent)        AS user_agent,
           MIN(e.created_at)        AS first_seen,
           MAX(e.created_at)        AS last_seen
    FROM security_events_tbl e
    WHERE $listWhere AND e.ip IS NOT NULL AND e.ip <> ''
    GROUP BY e.ip
    ORDER BY high DESC, n DESC
    LIMIT 15
", $listTypes, $listParams) ?? []);

// ── The events ───────────────────────────────────────────────
$eventTotal = (int) ((sec_query($conn, "
    SELECT COUNT(*) AS n FROM security_events_tbl e WHERE $listWhere
", $listTypes, $listParams) ?? [['n' => 0]])[0]['n'] ?? 0);

$lastPage = max(1, (int) ceil($eventTotal / SEC_PER_PAGE));
if ($page > $lastPage) $page = $lastPage;
$offset = ($page - 1) * SEC_PER_PAGE;

$events = sec_query($conn, "
    SELECT e.*, u.name AS user_name, u.email AS user_email
    FROM security_events_tbl e
    LEFT JOIN users u ON u.id = e.user_id
    WHERE $listWhere
    ORDER BY e.id DESC
    LIMIT ? OFFSET ?
", $listTypes . 'ii', array_merge($listParams, [SEC_PER_PAGE, $offset])) ?? [];

// ── The attendance side ──────────────────────────────────────
// Abuse of the attendance link is already logged, on the Integrity
// page. Counted here so this page is the one place to start, without
// copying those rows into a second table.
$integrityFlagged = null;
if (can('links.manage')) {
    $row = sec_query($conn, "
        SELECT COUNT(*) AS n FROM attendance_audit_tbl
        WHERE result IN ('device_reuse', 'lookup_limit', 'bad_link', 'no_student')
          AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
    ", 'i', [$days]);
    $integrityFlagged = $row === null ? null : (int) ($row[0]['n'] ?? 0);
}

$activeChips = [];
if ($ip !== '')    $activeChips[] = ['bi-geo-alt', 'IP ' . $ip, ['ip' => '']];
if (isset(SEC_EVENT_GROUPS[$event])) {
    $activeChips[] = [SEC_EVENT_GROUPS[$event][1], SEC_EVENT_GROUPS[$event][0], ['event' => '']];
} elseif ($event !== '') {
    $activeChips[] = [security_event_meta($event)[2], security_event_meta($event)[0], ['event' => '']];
}
?>
<!doctype html>
<html lang="en">

<head>
    <title>Security Monitor</title>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <?php /* The Integrity page's stylesheet, reused whole: the two pages
            are the same kind of screen — counts, a source table, an event
            log — and should look like one product. */ ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/attendance-integrity.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content ati-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="container-fluid px-3 px-md-4 py-3">

            <div class="ati-hero">
                <div class="ati-hero-icon"><i class="bi bi-shield-exclamation"></i></div>
                <div class="ati-hero-text">
                    <h2>Security Monitor</h2>
                    <p>Failed sign-ins, password guessing, actions someone was not allowed to do, and
                       requests carrying attack patterns — where they came from and what they aimed at.
                       Everything here was <strong>already blocked</strong>; this is the record of who tried.</p>
                </div>

                <div class="ati-range">
                    <?php foreach ([1 => 'Today', 7 => '7 days', 30 => '30 days'] as $d => $label): ?>
                        <a class="ati-range-btn <?= $days === $d ? 'is-on' : '' ?>"
                           href="<?= $url(['days' => $d, 'page' => null]) ?>"><?= $label ?></a>
                    <?php endforeach; ?>
                </div>
            </div>

            <?php if (!$ready): ?>
                <div class="ati-empty">
                    <i class="bi bi-database-exclamation"></i>
                    <h5>The security log could not be set up</h5>
                    <p>
                        The database refused to create <code>security_events_tbl</code>. Run
                        <code>migrations/2026-09-13_add_security_events.sql</code> in phpMyAdmin.
                        Nothing else is affected — the site keeps working, it just is not recording.
                    </p>
                </div>
            <?php else: ?>

                <?php if ($recentHigh > 0): ?>
                    <div class="ati-warn">
                        <i class="bi bi-exclamation-octagon"></i>
                        <div>
                            <strong><?= number_format($recentHigh) ?> high-severity
                                event<?= $recentHigh === 1 ? '' : 's' ?> in the last 24 hours.</strong>
                            Password guessing, a forged face sign-in, or a request carrying an attack
                            pattern. Check where they came from below.
                            <a href="<?= $url(['days' => 1, 'sev' => 'high', 'event' => '', 'page' => null]) ?>">Show them</a>
                        </div>
                    </div>
                <?php endif; ?>

                <div class="ati-stats">
                    <a class="ati-stat <?= $nHigh > 0 ? 'is-alert' : '' ?> <?= $sev === 'high' && $event === '' ? 'is-picked' : '' ?>"
                       href="<?= $url(['sev' => 'high', 'event' => '', 'page' => null]) ?>">
                        <span class="ati-stat-label">High severity</span>
                        <span class="ati-stat-figure"><?= number_format($nHigh) ?></span>
                        <span class="ati-stat-note">of <?= number_format($nTotal) ?> events</span>
                    </a>
                    <a class="ati-stat <?= $nGuessing > 0 ? 'is-alert' : ($nSignins > 0 ? 'is-warn' : '') ?> <?= $event === 'signin' ? 'is-picked' : '' ?>"
                       href="<?= $url(['event' => 'signin', 'sev' => 'all', 'page' => null]) ?>">
                        <span class="ati-stat-label">Failed sign-ins</span>
                        <span class="ati-stat-figure"><?= number_format($nSignins) ?></span>
                        <span class="ati-stat-note"><?= number_format($nGuessing) ?> flagged as guessing</span>
                    </a>
                    <a class="ati-stat <?= $nProbes > 0 ? 'is-alert' : '' ?> <?= $event === 'probe' ? 'is-picked' : '' ?>"
                       href="<?= $url(['event' => 'probe', 'sev' => 'all', 'page' => null]) ?>">
                        <span class="ati-stat-label">Attack patterns</span>
                        <span class="ati-stat-figure"><?= number_format($nProbes) ?></span>
                        <span class="ati-stat-note">SQL, script or path injection</span>
                    </a>
                    <a class="ati-stat <?= $nDenied > 0 ? 'is-warn' : '' ?> <?= $event === 'denied' ? 'is-picked' : '' ?>"
                       href="<?= $url(['event' => 'denied', 'sev' => 'all', 'page' => null]) ?>">
                        <span class="ati-stat-label">Blocked actions</span>
                        <span class="ati-stat-figure"><?= number_format($nDenied) ?></span>
                        <span class="ati-stat-note">reached past their permissions</span>
                    </a>
                    <?php if ($integrityFlagged !== null): ?>
                        <a class="ati-stat <?= $integrityFlagged > 0 ? 'is-warn' : '' ?>"
                           href="attendance_integrity.php?days=<?= $days ?>">
                            <span class="ati-stat-label">Attendance link</span>
                            <span class="ati-stat-figure"><?= number_format($integrityFlagged) ?></span>
                            <span class="ati-stat-note">flagged on Integrity &rarr;</span>
                        </a>
                    <?php else: ?>
                        <div class="ati-stat">
                            <span class="ati-stat-label">Sources</span>
                            <span class="ati-stat-figure"><?= number_format($nSources) ?></span>
                            <span class="ati-stat-note">different IP addresses</span>
                        </div>
                    <?php endif; ?>
                </div>

                <form class="ati-filters" method="get">
                    <input type="hidden" name="days" value="<?= $days ?>">
                    <?php if ($sev !== 'all'): ?>
                        <input type="hidden" name="sev" value="<?= htmlspecialchars($sev) ?>">
                    <?php endif; ?>

                    <label class="ati-field">
                        <i class="bi bi-funnel"></i>
                        <select name="event">
                            <option value="">Every kind of event</option>
                            <?php foreach (SEC_EVENT_GROUPS as $key => [$label]): ?>
                                <option value="<?= $key ?>" <?= $event === $key ? 'selected' : '' ?>><?= $label ?></option>
                            <?php endforeach; ?>
                            <?php foreach (SECURITY_EVENTS as $key => [$label]): ?>
                                <option value="<?= $key ?>" <?= $event === $key ? 'selected' : '' ?>><?= $label ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>

                    <label class="ati-field ati-field-grow">
                        <i class="bi bi-geo-alt"></i>
                        <input type="search" name="ip" value="<?= htmlspecialchars($ip) ?>"
                               placeholder="IP address — 203.0.113.9">
                    </label>

                    <button type="submit" class="ati-go">Apply</button>
                    <?php if ($activeChips || $sev !== 'all'): ?>
                        <a class="ati-clear" href="<?= $url(['ip' => '', 'event' => '', 'sev' => 'all', 'page' => null]) ?>">Clear</a>
                    <?php endif; ?>
                </form>

                <?php if ($activeChips): ?>
                    <div class="ati-chips">
                        <?php foreach ($activeChips as [$chipIcon, $chipLabel, $off]): ?>
                            <a class="ati-fchip" href="<?= $url($off + ['page' => null]) ?>">
                                <i class="bi <?= $chipIcon ?>"></i><?= htmlspecialchars($chipLabel) ?>
                                <i class="bi bi-x-lg"></i>
                            </a>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>

                <?php if ($ip === ''): ?>
                    <div class="ati-card">
                        <div class="ati-card-head">
                            <h3><i class="bi bi-geo-alt"></i> Where it came from</h3>
                            <span class="ati-count"><?= count($sources) ?></span>
                        </div>

                        <?php if (empty($sources)): ?>
                            <p class="ati-none">
                                <i class="bi bi-check2-circle"></i>
                                Nobody has tried anything in this view.
                            </p>
                        <?php else: ?>
                            <p class="ati-lede">
                                One wrong password from a school IP is a teacher who mistyped. The same
                                address trying several emails, or turning up under more than one kind of
                                event, is someone looking for a way in. A whole classroom shares one public
                                IP, so read the <em>Aimed at</em> column before assuming one person.
                            </p>
                            <div class="table-responsive">
                                <table class="table ati-table">
                                    <thead>
                                        <tr>
                                            <th>Source</th>
                                            <th>Events</th>
                                            <th>High</th>
                                            <th>Aimed at</th>
                                            <th>Last seen</th>
                                            <th></th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach ($sources as $s): ?>
                                            <?php
                                            $targets = (string) $s['targets'];
                                            if (mb_strlen($targets) > 120) $targets = mb_substr($targets, 0, 120) . '…';
                                            ?>
                                            <tr class="<?= (int) $s['high'] > 0 || (int) $s['kinds'] >= 3 ? 'is-hot' : '' ?>">
                                                <td>
                                                    <div class="ati-device"><code><?= htmlspecialchars((string) $s['ip']) ?></code></div>
                                                    <div class="ati-sub"><?= htmlspecialchars(sec_ua_label($s['user_agent'])) ?></div>
                                                </td>
                                                <td>
                                                    <span class="ati-pill"><?= (int) $s['n'] ?></span>
                                                    <div class="ati-sub">
                                                        <?= htmlspecialchars(implode(', ', array_map(
                                                            static fn($ev) => security_event_meta($ev)[0],
                                                            array_filter(explode(',', (string) $s['events']))
                                                        ))) ?>
                                                    </div>
                                                </td>
                                                <td><?= (int) $s['high'] ?></td>
                                                <td class="ati-sub"><?= htmlspecialchars($targets) ?></td>
                                                <td class="ati-when"><?= date('M j, g:i A', strtotime($s['last_seen'])) ?></td>
                                                <td class="text-end">
                                                    <a class="ati-open" href="<?= $url(['ip' => $s['ip'], 'page' => null]) ?>">
                                                        Open <i class="bi bi-arrow-right-short"></i>
                                                    </a>
                                                </td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        <?php endif; ?>
                    </div>
                <?php endif; ?>

                <div class="ati-card">
                    <div class="ati-card-head">
                        <h3><i class="bi bi-list-ul"></i> Events</h3>
                        <span class="ati-count"><?= number_format($eventTotal) ?></span>
                        <div class="ati-tabs">
                            <?php foreach (['all' => 'All', 'high' => 'High', 'medium' => 'Medium', 'low' => 'Low'] as $key => $label): ?>
                                <a class="ati-tab <?= $sev === $key ? 'is-on' : '' ?>"
                                   href="<?= $url(['sev' => $key, 'page' => null]) ?>"><?= $label ?></a>
                            <?php endforeach; ?>
                        </div>
                    </div>

                    <?php if (empty($events)): ?>
                        <p class="ati-none">
                            <i class="bi bi-check2-circle"></i>
                            Nothing recorded in this view.
                        </p>
                    <?php else: ?>
                        <div class="table-responsive">
                            <table class="table ati-table">
                                <thead>
                                    <tr>
                                        <th>When</th>
                                        <th>Event</th>
                                        <th>Aimed at</th>
                                        <th>Who</th>
                                        <th>Detail</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($events as $e): ?>
                                        <?php [$evLabel, $evSev, $evIcon] = security_event_meta($e['event']); ?>
                                        <tr>
                                            <td class="ati-when"><?= date('M j, g:i:s A', strtotime($e['created_at'])) ?></td>
                                            <td>
                                                <span class="ati-chip is-<?= sec_chip_kind($e['severity']) ?>">
                                                    <i class="bi <?= $evIcon ?>"></i><?= htmlspecialchars($evLabel) ?>
                                                </span>
                                            </td>
                                            <td>
                                                <div class="ati-name"><?= htmlspecialchars((string) ($e['identifier'] ?? '—')) ?></div>
                                                <div class="ati-sub"><code><?= htmlspecialchars((string) $e['path']) ?></code></div>
                                            </td>
                                            <td>
                                                <?php if (!empty($e['user_name'])): ?>
                                                    <div><?= htmlspecialchars($e['user_name']) ?></div>
                                                <?php else: ?>
                                                    <div class="ati-sub">Not signed in</div>
                                                <?php endif; ?>
                                                <div class="ati-sub">
                                                    <a href="<?= $url(['ip' => $e['ip'], 'page' => null]) ?>"><?= htmlspecialchars((string) $e['ip']) ?></a>
                                                    · <?= htmlspecialchars(sec_ua_label($e['user_agent'])) ?>
                                                </div>
                                            </td>
                                            <td class="ati-sub" style="max-width: 22rem; word-break: break-word;">
                                                <?= htmlspecialchars((string) $e['detail']) ?>
                                            </td>
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
                    <?php endif; ?>

                    <p class="ati-foot">
                        <i class="bi bi-clock-history"></i>
                        The log keeps the last <?= SECURITY_LOG_DAYS ?> days. A source that repeats the same
                        thing is recorded <?= SECURITY_LOG_BURST ?> times per 10 minutes, not every time.
                    </p>
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
