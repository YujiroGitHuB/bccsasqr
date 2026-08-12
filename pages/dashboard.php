<?php require_once __DIR__ . '/../includes/asset.php';


session_start();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

$role      = $_SESSION['role'];
$user_id   = $_SESSION['user_id'];
$user_name = $_SESSION['user_name'];

date_default_timezone_set('Asia/Manila');
$today         = date('Y-m-d');

// Validate filter_date strictly as Y-m-d — this value is interpolated into
// several queries below, so anything non-conforming falls back to today.
$selected_date = $today;
if (isset($_GET['filter_date'])) {
    $d = DateTime::createFromFormat('Y-m-d', $_GET['filter_date']);
    if ($d && $d->format('Y-m-d') === $_GET['filter_date']) {
        $selected_date = $_GET['filter_date'];
    }
}

// ── Subjects ──────────────────────────────────────────────
$user_subjects = [];
if ($role === 'admin') {
    $subjects_query = $conn->query("
        SELECT DISTINCT s.subject_code, s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        ORDER BY s.subject_name
    ");
    while ($row = $subjects_query->fetch_assoc()) {
        $user_subjects[$row['subject_code']] = $row['subject_name'];
    }
} else {
    $sq = $conn->prepare("
        SELECT s.subject_code, s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        WHERE si.instructor_id = ?
    ");
    $sq->bind_param("i", $user_id);
    $sq->execute();
    $r = $sq->get_result();
    while ($row = $r->fetch_assoc()) {
        $user_subjects[$row['subject_code']] = $row['subject_name'];
    }
}
$has_subjects  = count($user_subjects) > 0;
$subject_names = array_values($user_subjects);

// ── Sections ──────────────────────────────────────────────
// ✅ FIXED: CONCAT course + section to form "BSIT-1A"
$user_sections = [];
if ($role === 'admin') {
    // Admin sees all sections
    $secq = $conn->query("
        SELECT DISTINCT CONCAT(course, '-', section) as full_section
        FROM instructor_section_tbl
        ORDER BY course, section
    ");
    while ($row = $secq->fetch_assoc()) {
        $user_sections[] = $row['full_section'];
    }
} else {
    $secq = $conn->prepare("
        SELECT CONCAT(course, '-', section) as full_section
        FROM instructor_section_tbl
        WHERE instructor_id = ?
        ORDER BY course, section
    ");
    $secq->bind_param("i", $user_id);
    $secq->execute();
    $r = $secq->get_result();
    while ($row = $r->fetch_assoc()) {
        $user_sections[] = $row['full_section'];
    }
}
$has_sections = count($user_sections) > 0;

// ── View Mode ─────────────────────────────────────────────
$default_view    = ($role === 'admin') ? 'sections' : ($has_subjects ? 'subjects' : 'sections');
// Allowlist the view — it is echoed back into links/inputs below.
$view_mode       = (isset($_GET['view']) && in_array($_GET['view'], ['sections', 'subjects'], true))
    ? $_GET['view'] : $default_view;
$can_switch_view = ($has_subjects && $has_sections) || ($role === 'admin' && $has_subjects);

// ── Top Metrics ───────────────────────────────────────────
// $trend_where is the SAME scope as the counts above. One source, so
// the KPIs and the trend chart below them can never disagree.
$trend_where = null;

if ($view_mode === 'sections') {
    if ($role === 'admin') {
        $totalStudent          = $conn->query("SELECT COUNT(DISTINCT student_no) AS total FROM students_tbl WHERE user_id = '$user_id'")->fetch_assoc()['total'];
        // A single scan of attendance_tbl for both counts — the WHERE
        // is identical, only the date is added.
        $m = $conn->query("
            SELECT COUNT(DISTINCT student_no) AS total,
                   COUNT(DISTINCT CASE WHEN DATE(date) = '$selected_date' THEN student_no END) AS present
            FROM attendance_tbl
            WHERE user_id = '$user_id'
        ")->fetch_assoc();
        $totalStudents         = $m['total'];
        $presentOnSelectedDate = $m['present'];
        $trend_where           = "user_id = '$user_id'";
    } elseif ($has_sections) {
        // ✅ FIXED: use full_section in IN clause
        $sections_in           = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $user_sections)) . "'";
        $totalStudent          = $conn->query("SELECT COUNT(DISTINCT student_no) as total FROM students_tbl WHERE CONCAT(course,'-',section) IN ($sections_in)")->fetch_assoc()['total'];
        // ✅ FIXED: attendance_tbl.section stores raw "1A" — use CONCAT to match "BSIT-1A"
        // Merged into one scan — identical WHERE, only the date added.
        $m = $conn->query("
            SELECT COUNT(DISTINCT student_no) AS total,
                   COUNT(DISTINCT CASE WHEN DATE(date) = '$selected_date' THEN student_no END) AS present
            FROM attendance_tbl
            WHERE CONCAT(course,'-',section) IN ($sections_in) AND user_id = '$user_id'
        ")->fetch_assoc();
        $totalStudents         = $m['total'];
        $presentOnSelectedDate = $m['present'];
        $trend_where           = "CONCAT(course,'-',section) IN ($sections_in) AND user_id = '$user_id'";
    } else {
        $totalStudent = $totalStudents = $presentOnSelectedDate = 0;
    }
} else {
    if ($has_subjects) {
        $subjects_in           = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $subject_names)) . "'";
        // Merged into one scan — identical WHERE, only the date added.
        $m = $conn->query("
            SELECT COUNT(DISTINCT student_no) AS total,
                   COUNT(DISTINCT CASE WHEN DATE(date) = '$selected_date' THEN student_no END) AS present
            FROM attendance_tbl
            WHERE subject IN ($subjects_in) AND user_id = '$user_id'
        ")->fetch_assoc();
        $totalStudent          = $m['total'];
        $totalStudents         = $totalStudent;
        $presentOnSelectedDate = $m['present'];
        $trend_where           = "subject IN ($subjects_in) AND user_id = '$user_id'";
    } else {
        $totalStudent = $totalStudents = $presentOnSelectedDate = 0;
    }
}

// ── Helper: detect year level from full_section (e.g. "BSIT-1A" → "1st Year") ──
// ✅ FIXED: extract section part after '-' for year detection
function getYearLevel(string $full_section): string {
    // Extract raw section part after last '-'
    $parts = explode('-', $full_section);
    $sec   = end($parts); // e.g. "1A", "2B", "3C"

    if (preg_match('/^1/', $sec)) return '1st Year';
    if (preg_match('/^2/', $sec)) return '2nd Year';
    if (preg_match('/^3/', $sec)) return '3rd Year';
    if (preg_match('/^4/', $sec)) return '4th Year';
    return 'Other';
}

// ============================================================
//  ATTENDANCE TREND (14 days up to the selected date)
//
//  This is the one question the numbers above cannot answer: they
//  are all a snapshot of a single day. The line says whether things
//  are going up or down.
//
//  It shows the COUNT of students who scanned, not a percentage:
//  the denominator would be 1,762 students while only a handful of
//  sections have class on any given day — attendance would look
//  like it had collapsed to 5% when it had not.
// ============================================================
$trend_from   = date('Y-m-d', strtotime($selected_date . ' -13 days'));
$trend_series = [];   // ['label' => ..., 'iso' => ..., 'value' => int]
$trend_days   = 0;    // how many days had at least one scan

if ($trend_where !== null) {
    // A single query; attendance_tbl has idx_section_date(date).
    $tq = $conn->query("
        SELECT DATE(date) AS d, COUNT(DISTINCT student_no) AS n
        FROM attendance_tbl
        WHERE ($trend_where)
          AND DATE(date) BETWEEN '$trend_from' AND '$selected_date'
        GROUP BY DATE(date)
    ");

    $byDate = [];
    if ($tq) {
        while ($row = $tq->fetch_assoc()) {
            $byDate[$row['d']] = (int)$row['n'];
        }
    }

    // Fill the whole calendar: a day with no scans is a genuine
    // zero, and the points must be evenly spaced on x — a line that
    // skips dates lies.
    for ($i = 13; $i >= 0; $i--) {
        $iso = date('Y-m-d', strtotime($selected_date . " -$i days"));
        $val = $byDate[$iso] ?? 0;
        if ($val > 0) $trend_days++;

        $trend_series[] = [
            'iso'   => $iso,
            'label' => date('M j', strtotime($iso)),
            'full'  => date('D, M j, Y', strtotime($iso)),
            'value' => $val,
        ];
    }
}

// Two days is the minimum before there is any "trend" to speak of —
// a single point is not a line.
$trend_ready = $trend_days >= 2;

// ── Helper: a stable color per section ───────────────────────
// Only a marker, so a card can be picked out quickly in a long
// list. The old palette held pastels (e.g. #a8edea, #fed6e3) that
// left white text almost unreadable — only tints that suit a dark
// background remain.
function sectionAccent(string $section): array {
    $palette = [
        [102, 126, 234],  // indigo
        [16, 185, 129],   // emerald
        [6, 182, 212],    // cyan
        [244, 114, 182],  // pink
        [245, 158, 11],   // amber
        [139, 92, 246],   // violet
    ];
    [$r, $g, $b] = $palette[crc32($section) % count($palette)];

    return [
        'solid' => "rgb($r,$g,$b)",
        'soft'  => "rgba($r,$g,$b,.14)",
        'line'  => "rgba($r,$g,$b,.34)",
    ];
}

// ============================================================
//  PRE-LOAD SECTION STATS
// ============================================================
$section_stats_map = [];

if ($view_mode === 'sections' && ($has_sections || $role === 'admin')) {

    if ($role === 'admin') {
        $att_where = "user_id = '$user_id'";
        // ✅ FIXED: students_tbl uses course+section, attendance_tbl uses full_section
        $stu_where = "1=1";
    } else {
        $sections_in = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $user_sections)) . "'";
        // ✅ FIXED: attendance_tbl.section is raw "1A" — use CONCAT to match "BSIT-1A"
        $att_where   = "CONCAT(course,'-',section) IN ($sections_in) AND user_id = '$user_id'";
        $stu_where   = "CONCAT(course,'-',section) IN ($sections_in)";
    }

    // BATCH 1 — active students + total SESSIONS per section
    //
    // A session is (subject, date), not a date. Counting distinct dates
    // meant a student who attended one subject and skipped another on
    // the same day was counted present for that day — see
    // includes/absences.php. The "3+ absent" / "5+ absent" counts on
    // the section cards were understated because of it.
    $b1 = $conn->query("
        SELECT
            CONCAT(course,'-',section) AS section,
            COUNT(DISTINCT student_no)                        AS active_students,
            COUNT(DISTINCT COALESCE(subject,''), DATE(date))  AS total_classes
        FROM attendance_tbl
        WHERE $att_where
        GROUP BY course, section
    ");
    while ($row = $b1->fetch_assoc()) {
        $section_stats_map[$row['section']] = [
            'active_students'     => (int)$row['active_students'],
            'total_classes'       => (int)$row['total_classes'],
            'students_3_absences' => 0,
            'students_5_absences' => 0,
        ];
    }

    // BATCH 2a — sessions attended per student per section
    // Must use the same session definition as BATCH 1, or the
    // subtraction in BATCH 2c compares two different units.
    $attended_map = [];
    $b2a = $conn->query("
        SELECT CONCAT(course,'-',section) AS section, student_no,
               COUNT(DISTINCT COALESCE(subject,''), DATE(date)) AS attended
        FROM attendance_tbl
        WHERE $att_where
        GROUP BY course, section, student_no
    ");
    if ($b2a) {
        while ($row = $b2a->fetch_assoc()) {
            $attended_map[$row['section']][$row['student_no']] = (int)$row['attended'];
        }
    }

    // BATCH 2b — all students per section
    // ✅ FIXED: select CONCAT(course,'-',section) as section key
    $all_students = [];
    $b2b = $conn->query("
        SELECT CONCAT(course,'-',section) as full_section, student_no
        FROM students_tbl
        WHERE $stu_where
    ");
    if ($b2b) {
        while ($row = $b2b->fetch_assoc()) {
            $all_students[$row['full_section']][] = $row['student_no'];
        }
    }

    // BATCH 2c — calculate absences in PHP
    foreach ($section_stats_map as $sec => $data) {
        $tc       = (int)$data['total_classes'];
        $count_3  = 0;
        $count_5  = 0;
        $students = $all_students[$sec] ?? [];

        foreach ($students as $sno) {
            $attended = $attended_map[$sec][$sno] ?? 0;
            $absences = $tc - $attended;
            if ($absences >= 3) $count_3++;
            if ($absences >= 5) $count_5++;
        }

        $section_stats_map[$sec]['students_3_absences'] = $count_3;
        $section_stats_map[$sec]['students_5_absences'] = $count_5;
    }
}
// ============================================================
//  END BATCH PRE-LOAD
// ============================================================
?>
<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/dashboard.css') ?>">
    <!-- Anyo ng view_absences_modal.php (klase: .app-modal) -->
    <link rel="stylesheet" href="<?= asset('../assets/css/modal-form.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../includes/alert.php"; ?>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content dash-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="dash-hero">
            <div class="dash-hero-icon"><i class="bi bi-speedometer2"></i></div>
            <div class="dash-hero-text">
                <h2>Dashboard</h2>
                <p>Welcome back, <?= htmlspecialchars($_SESSION['user_name']) ?>!</p>
                <?php if ($has_subjects || $has_sections): ?>
                    <div class="dash-chips">
                        <?php if ($has_subjects): ?>
                            <span class="dash-chip green">
                                <i class="bi bi-book-fill"></i>
                                <?= count($user_subjects) ?> Subject<?= count($user_subjects) > 1 ? 's' : '' ?>
                            </span>
                        <?php endif; ?>
                        <?php if ($has_sections): ?>
                            <span class="dash-chip">
                                <i class="bi bi-grid-3x3"></i>
                                <?= count($user_sections) ?> Section<?= count($user_sections) > 1 ? 's' : '' ?>
                            </span>
                        <?php endif; ?>
                    </div>
                <?php endif; ?>
            </div>

            <?php if ($can_switch_view): ?>
                <div class="dash-switch">
                    <a href="?view=sections<?= isset($_GET['filter_date']) ? '&filter_date=' . urlencode($selected_date) : '' ?>"
                        class="<?= $view_mode === 'sections' ? 'active' : '' ?>">
                        <i class="bi bi-grid-3x3"></i><span>Section Overview</span>
                    </a>
                    <a href="?view=subjects<?= isset($_GET['filter_date']) ? '&filter_date=' . urlencode($selected_date) : '' ?>"
                        class="<?= $view_mode === 'subjects' ? 'active' : '' ?>">
                        <i class="bi bi-book"></i><span>Subject Details</span>
                    </a>
                </div>
            <?php endif; ?>
        </div>

        <div class="container-fluid p-0">

            <!-- ── KPI ────────────────────────────────────────────
                 The second and third cards are ratios, so the
                 percentage is spelled out — only the bar carried that
                 before, and the eye had to estimate it. -->
            <?php
            $scanRate    = $totalStudent  > 0 ? round($totalStudents / $totalStudent * 100) : 0;
            $presentRate = $totalStudents > 0 ? round($presentOnSelectedDate / $totalStudents * 100) : 0;
            ?>
            <div class="dash-kpis">
                <div class="dash-kpi" style="--kpi:linear-gradient(135deg,#667eea,#764ba2);--kpi-glow:rgba(102,126,234,.6)">
                    <div class="dash-kpi-top">
                        <div class="dash-kpi-icon"><i class="bi bi-people-fill"></i></div>
                        <div>
                            <div class="dash-kpi-label"><?= $view_mode === 'subjects' ? 'Unique Students' : 'Total Students' ?></div>
                            <div class="dash-kpi-value"><?= number_format($totalStudent) ?></div>
                        </div>
                    </div>
                    <div class="dash-kpi-foot">
                        <span><?= $view_mode === 'subjects' ? 'Across your subjects' : 'Across your sections' ?></span>
                    </div>
                    <div class="dash-bar"><span style="width:100%"></span></div>
                </div>

                <div class="dash-kpi" style="--kpi:linear-gradient(135deg,#0dcaf0,#0aa2c0);--kpi-glow:rgba(13,202,240,.6)">
                    <div class="dash-kpi-top">
                        <div class="dash-kpi-icon"><i class="bi bi-qr-code-scan"></i></div>
                        <div>
                            <div class="dash-kpi-label">Total Scanned</div>
                            <div class="dash-kpi-value"><?= number_format($totalStudents) ?></div>
                        </div>
                    </div>
                    <div class="dash-kpi-foot">
                        <span>Scanned at least once</span>
                        <b><?= $scanRate ?>%</b>
                    </div>
                    <div class="dash-bar"><span style="width:<?= min(100, $scanRate) ?>%"></span></div>
                </div>

                <div class="dash-kpi" style="--kpi:linear-gradient(135deg,#10b981,#059669);--kpi-glow:rgba(16,185,129,.6)">
                    <div class="dash-kpi-top">
                        <div class="dash-kpi-icon"><i class="bi bi-person-check-fill"></i></div>
                        <div>
                            <div class="dash-kpi-label"><?= $selected_date == $today ? 'Present Today' : 'Present on Date' ?></div>
                            <div class="dash-kpi-value"><?= number_format($presentOnSelectedDate) ?></div>
                        </div>
                    </div>
                    <div class="dash-kpi-foot">
                        <span><?= date('M d, Y', strtotime($selected_date)) ?></span>
                        <b><?= $presentRate ?>%</b>
                    </div>
                    <div class="dash-bar"><span style="width:<?= min(100, $presentRate) ?>%"></span></div>
                </div>
            </div>

            <!-- ── Toolbar: pamagat ng view + petsa ───────────────
                 This used to be three boxes: a "Filter Overview"
                 header, the date panel, and the "Currently Viewing"
                 card — all saying which date is being looked at. -->
            <div class="dash-toolbar">
                <div class="dash-toolbar-title">
                    <i class="bi bi-clipboard-data"></i>
                    <div>
                        <h5><?= $view_mode === 'subjects' ? 'Subject Attendance Details' : 'Section Overview' ?></h5>
                        <small><?= date('l, F d, Y', strtotime($selected_date)) ?></small>
                    </div>
                </div>

                <form method="GET" action="" class="dash-date-form" id="dateFilterForm">
                    <?php if (isset($_GET['view'])): ?>
                        <input type="hidden" name="view" value="<?= htmlspecialchars($view_mode) ?>">
                    <?php endif; ?>

                    <label class="dash-date">
                        <i class="bi bi-calendar3"></i>
                        <input type="date" name="filter_date" id="filter_date"
                            value="<?= $selected_date ?>" max="<?= $today ?>"
                            onchange="document.getElementById('dateFilterForm').submit()">
                    </label>

                    <?php if ($selected_date != $today): ?>
                        <button type="button" class="dash-today"
                            onclick="window.location.href='?<?= isset($_GET['view']) ? 'view=' . $view_mode : '' ?>'">
                            <i class="bi bi-arrow-clockwise me-1"></i>Today
                        </button>
                        <span class="dash-live past"><i class="bi bi-archive"></i> Historical</span>
                    <?php else: ?>
                        <span class="dash-live"><span class="dot"></span> Live Today</span>
                    <?php endif; ?>
                </form>
            </div>

            <!-- ── Attendance trend ───────────────────────────────
                 BELOW the toolbar, because the date filter above sets
                 the end of the 14-day window — a control belongs above
                 everything it governs, and there is no separate filter
                 inside the card. -->
            <section class="dash-trend">
                <div class="dash-trend-head">
                    <div>
                        <h5>Attendance trend</h5>
                        <small>
                            Students who scanned per day ·
                            <?= date('M j', strtotime($trend_from)) ?> – <?= date('M j, Y', strtotime($selected_date)) ?>
                        </small>
                    </div>
                </div>

                <?php if ($trend_ready): ?>
                    <div class="dash-chart">
                        <canvas id="attendanceTrend"
                            role="img"
                            aria-label="Line chart of students who scanned per day over 14 days. Exact values are in the table below."></canvas>
                    </div>

                    <!-- The tooltip is supplementary, not the only route
                         to the value — the full data is here. -->
                    <details class="dash-table-view">
                        <summary>Show as table</summary>
                        <table>
                            <thead>
                                <tr>
                                    <th>Date</th>
                                    <th>Scanned</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($trend_series as $pt): ?>
                                    <tr>
                                        <td><?= htmlspecialchars($pt['full']) ?></td>
                                        <td><?= number_format($pt['value']) ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </details>
                <?php else: ?>
                    <div class="dash-empty">
                        <i class="bi bi-graph-up"></i>
                        <strong>Not enough data for a trend</strong>
                        <span>
                            <?= $trend_days === 1
                                ? 'Only one day in this window has scans — at least two are needed.'
                                : 'No scans yet in this 14-day window.' ?>
                        </span>
                    </div>
                <?php endif; ?>
            </section>

            <!-- CARDS -->
            <div class="row g-3">
                <?php
                if ($view_mode === 'sections') {

                    if ($role === 'admin') {
                        $stmt = $conn->prepare("
                            SELECT CONCAT(course,'-',section) as section,
                                   COUNT(DISTINCT student_no) AS total
                            FROM students_tbl
                            WHERE user_id = ?
                            GROUP BY course, section
                            ORDER BY course, section
                        ");
                        $stmt->bind_param("i", $user_id);
                    } else {
                        $sections_in = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $user_sections)) . "'";
                        $stmt = $conn->prepare("
                            SELECT CONCAT(course,'-',section) as section,
                                   COUNT(DISTINCT student_no) AS total
                            FROM students_tbl
                            WHERE CONCAT(course,'-',section) IN ($sections_in)
                            GROUP BY course, section
                            ORDER BY course, section
                        ");
                    }
                    $stmt->execute();
                    $result = $stmt->get_result();

                    $sections_by_year = ['1st Year' => [], '2nd Year' => [], '3rd Year' => [], '4th Year' => [], 'Other' => []];

                    if ($result && $result->num_rows > 0) {
                        while ($row = $result->fetch_assoc()) {
                            $sec   = $row['section']; // now "BSIT-1A"
                            $total = $row['total'];

                            $stats               = $section_stats_map[$sec] ?? [];
                            $active_students     = $stats['active_students']     ?? 0;
                            $total_classes       = $stats['total_classes']       ?? 0;
                            $students_3_absences = $stats['students_3_absences'] ?? 0;
                            $students_5_absences = $stats['students_5_absences'] ?? 0;
                            $never_attended      = max(0, $total - $active_students);
                            $engagement_rate     = $total > 0 ? round(($active_students / $total) * 100, 1) : 0;

                            // ✅ FIXED: use helper function for year detection
                            $yr = getYearLevel($sec);

                            if (!isset($sections_by_year[$yr])) $sections_by_year[$yr] = [];
                            $sections_by_year[$yr][] = compact(
                                'sec', 'total', 'active_students', 'never_attended',
                                'engagement_rate', 'total_classes',
                                'students_3_absences', 'students_5_absences'
                            );
                        }

                        foreach ($sections_by_year as $year => $secs) {
                            if (empty($secs)) continue;

                            echo '<div class="col-12">
                                    <div class="dash-year">
                                      <i class="bi bi-mortarboard-fill" style="color:#818cf8"></i>
                                      <h4>' . $year . '</h4>
                                      <span>' . count($secs) . ' section' . (count($secs) > 1 ? 's' : '') . '</span>
                                    </div>
                                  </div>';

                            foreach ($secs as $sd):
                                $section             = $sd['sec'];
                                $total               = $sd['total'];
                                $active_students     = $sd['active_students'];
                                $never_attended      = $sd['never_attended'];
                                $engagement_rate     = $sd['engagement_rate'];
                                $total_classes       = $sd['total_classes'];
                                $students_3_absences = $sd['students_3_absences'];
                                $students_5_absences = $sd['students_5_absences'];

                                $cs = sectionAccent($section);
                ?>
                                <div class="col-xl-3 col-lg-4 col-md-6">
                                    <div class="dash-card"
                                        style="--tag:<?= $cs['solid'] ?>;--tag-soft:<?= $cs['soft'] ?>;--tag-line:<?= $cs['line'] ?>">

                                        <div class="dash-card-head">
                                            <span class="dash-tag">
                                                <i class="bi bi-grid-3x3-gap-fill"></i>
                                                <?= htmlspecialchars($section) ?>
                                            </span>
                                            <small><?= $total_classes ?> class<?= $total_classes == 1 ? '' : 'es' ?></small>
                                        </div>

                                        <?php if (!$has_subjects): ?>
                                            <div class="dash-notice warn mb-3" style="font-size:.78rem;padding:.6rem .8rem">
                                                <i class="bi bi-info-circle-fill"></i>
                                                <span>No subjects assigned yet.</span>
                                            </div>
                                        <?php endif; ?>

                                        <!-- These three figures are the card's content, no longer
                                             hidden inside a collapse — they are what gets looked at
                                             first. -->
                                        <div class="dash-mini">
                                            <div>
                                                <b><?= number_format($total) ?></b>
                                                <small>Enrolled</small>
                                            </div>
                                            <div class="ok">
                                                <b><?= number_format($active_students) ?></b>
                                                <small>Active</small>
                                            </div>
                                            <div class="warn">
                                                <b><?= number_format($never_attended) ?></b>
                                                <small>Never</small>
                                            </div>
                                        </div>

                                        <div class="dash-engage">
                                            <div class="dash-engage-top">
                                                <span>Engagement</span>
                                                <b><?= $engagement_rate ?>%</b>
                                            </div>
                                            <div class="dash-bar"><span style="width:<?= min(100, $engagement_rate) ?>%"></span></div>
                                        </div>

                                        <div class="dash-risks">
                                            <a href="#" class="dash-risk warn"
                                                onclick="viewAbsences('<?= htmlspecialchars($section) ?>',3); return false;"
                                                title="View and export the list">
                                                <i class="bi bi-exclamation-circle-fill"></i>
                                                <span class="n">
                                                    <b><?= number_format($students_3_absences) ?></b>
                                                    <small>3+ absent</small>
                                                </span>
                                            </a>
                                            <a href="#" class="dash-risk crit"
                                                onclick="viewAbsences('<?= htmlspecialchars($section) ?>',5); return false;"
                                                title="Critical — view and export">
                                                <i class="bi bi-x-octagon-fill"></i>
                                                <span class="n">
                                                    <b><?= number_format($students_5_absences) ?></b>
                                                    <small>5+ absent</small>
                                                </span>
                                            </a>
                                        </div>
                                    </div>
                                </div>
                                <?php
                            endforeach;
                        }
                    } else {
                        echo '<div class="col-12"><div class="dash-notice">
                                <i class="bi bi-info-circle-fill"></i>
                                <span>No sections assigned yet.</span>
                              </div></div>';
                    }

                } elseif ($view_mode === 'subjects') {
                    if ($has_subjects) {
                        $subjects_in = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $subject_names)) . "'";

                        if ($role === 'admin') {
                            // ✅ FIX: attendance_tbl stores section="1A" and course="BSIT" separately
                            // JOIN on both course+section; display CONCAT as full_section
                            $stmt = $conn->prepare("
                                SELECT a.subject,
                                       CONCAT(a.course, '-', a.section) AS section,
                                       COUNT(DISTINCT s.student_no) AS total_students,
                                       COUNT(DISTINCT CASE WHEN DATE(a.date) = ? THEN a.student_no END) AS present
                                FROM attendance_tbl a
                                INNER JOIN students_tbl s
                                    ON s.section = a.section AND s.course = a.course
                                WHERE a.subject IN ($subjects_in)
                                GROUP BY a.subject, a.course, a.section
                                ORDER BY a.course, a.section, a.subject
                            ");
                            $stmt->bind_param("s", $selected_date);
                        } else {
                            $stmt = $conn->prepare("
                                SELECT a.subject,
                                       CONCAT(a.course, '-', a.section) AS section,
                                       COUNT(DISTINCT s.student_no) AS total_students,
                                       COUNT(DISTINCT CASE WHEN DATE(a.date) = ? THEN a.student_no END) AS present
                                FROM attendance_tbl a
                                INNER JOIN students_tbl s
                                    ON s.section = a.section AND s.course = a.course
                                WHERE a.subject IN ($subjects_in) AND a.user_id = ?
                                GROUP BY a.subject, a.course, a.section
                                ORDER BY a.course, a.section, a.subject
                            ");
                            $stmt->bind_param("si", $selected_date, $user_id);
                        }
                        $stmt->execute();
                        $result = $stmt->get_result();

                        if ($result->num_rows > 0):
                            $current_year = $current_subject = null;
                            while ($row = $result->fetch_assoc()):
                                $subject         = $row['subject'];
                                $section         = $row['section']; // "BSIT-1A"
                                $total_students  = $row['total_students'];
                                $present_on_date = $row['present'];
                                $absent_on_date  = max(0, $total_students - $present_on_date);

                                // ✅ FIXED: use helper
                                $yr = getYearLevel($section);

                                if ($current_year !== $yr): $current_year = $yr;
                                    $current_subject = null; ?>
                                    <div class="col-12">
                                        <div class="dash-year">
                                            <i class="bi bi-mortarboard-fill" style="color:#818cf8"></i>
                                            <h4><?= $yr ?></h4>
                                        </div>
                                    </div>
                                <?php endif; ?>

                                <?php if ($current_subject !== $subject): $current_subject = $subject; ?>
                                    <div class="col-12">
                                        <div class="dash-subject-bar">
                                            <i class="bi bi-book-fill"></i>
                                            <?= htmlspecialchars($subject) ?>
                                        </div>
                                    </div>
                                <?php endif; ?>

                                <?php $attRate = $total_students > 0 ? round($present_on_date / $total_students * 100) : 0; ?>
                                <div class="col-xl-4 col-md-6">
                                    <div class="dash-card">
                                        <div class="dash-card-head">
                                            <span class="dash-tag">
                                                <i class="bi bi-grid-3x3-gap-fill"></i>
                                                <?= htmlspecialchars($section) ?>
                                            </span>
                                            <small><?= number_format($total_students) ?> students</small>
                                        </div>

                                        <!-- Both tiles are still clickable for the list; the PDF
                                             action sits separately below. -->
                                        <div class="dash-splits">
                                            <a href="#" class="dash-split present"
                                                onclick="viewAttendance('<?= htmlspecialchars($subject) ?>','<?= htmlspecialchars($section) ?>','present','<?= $selected_date ?>'); return false;">
                                                <i class="bi bi-check-circle-fill"></i>
                                                <b><?= number_format($present_on_date) ?></b>
                                                <small>Present</small>
                                            </a>
                                            <a href="#" class="dash-split absent"
                                                onclick="viewAttendance('<?= htmlspecialchars($subject) ?>','<?= htmlspecialchars($section) ?>','absent','<?= $selected_date ?>'); return false;">
                                                <i class="bi bi-x-circle-fill"></i>
                                                <b><?= number_format($absent_on_date) ?></b>
                                                <small>Absent</small>
                                            </a>
                                        </div>

                                        <div class="dash-engage">
                                            <div class="dash-engage-top">
                                                <span>Attendance rate</span>
                                                <b><?= $attRate ?>%</b>
                                            </div>
                                            <div class="dash-bar"><span style="width:<?= min(100, $attRate) ?>%"></span></div>
                                        </div>

                                        <div class="dash-exports">
                                            <form action="../exports/export_pdf.php" method="POST">
                                                <input type="hidden" name="subject" value="<?= htmlspecialchars($subject) ?>">
                                                <input type="hidden" name="section" value="<?= htmlspecialchars($section) ?>">
                                                <input type="hidden" name="status" value="present">
                                                <input type="hidden" name="date" value="<?= $selected_date ?>">
                                                <button type="submit" class="dash-export present">
                                                    <i class="bi bi-file-earmark-pdf"></i> Present PDF
                                                </button>
                                            </form>
                                            <form action="../exports/export_pdf.php" method="POST">
                                                <input type="hidden" name="subject" value="<?= htmlspecialchars($subject) ?>">
                                                <input type="hidden" name="section" value="<?= htmlspecialchars($section) ?>">
                                                <input type="hidden" name="status" value="absent">
                                                <input type="hidden" name="date" value="<?= $selected_date ?>">
                                                <button type="submit" class="dash-export absent">
                                                    <i class="bi bi-file-earmark-pdf"></i> Absent PDF
                                                </button>
                                            </form>
                                        </div>
                                    </div>
                                </div>
                            <?php
                            endwhile;
                        else: ?>
                            <div class="col-12">
                                <div class="dash-notice">
                                    <i class="bi bi-info-circle-fill"></i>
                                    <span>No attendance records for your subjects yet.</span>
                                </div>
                            </div>
                        <?php endif;
                    } else {
                        echo '<div class="col-12"><div class="dash-notice">
                                <i class="bi bi-info-circle-fill"></i>
                                <span>No subjects assigned yet.</span>
                              </div></div>';
                    }
                }
                ?>
            </div>

            <?php include __DIR__ . "/../components/view_attendance_modal.php"; ?>
            <?php include __DIR__ . "/../components/view_absences_modal.php"; ?>

            <div class="dash-section-title mt-5">
                Recent Activity
                <span class="count">Last 5 scans today</span>
            </div>

            <div class="row g-3">
                <div class="col-12">
                    <div class="dash-activity">
                        <div>
                            <?php
                            if ($has_subjects) {
                                $subjects_in = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $subject_names)) . "'";
                                $recentLogs  = $conn->query("
                                    SELECT a.student_no, a.name, a.course, a.section, a.subject, a.time_in,
                                           u.name AS instructor_name
                                    FROM attendance_tbl a
                                    LEFT JOIN users u ON a.user_id = u.id
                                    WHERE a.subject IN ($subjects_in) AND a.user_id = '$user_id'
                                      AND DATE(a.date) = '$today'
                                    ORDER BY a.id DESC LIMIT 5
                                ");
                            } elseif ($role === 'admin') {
                                $recentLogs = $conn->query("
                                    SELECT a.student_no, a.name, a.course, a.section, a.subject, a.time_in,
                                           u.name AS instructor_name
                                    FROM attendance_tbl a
                                    LEFT JOIN users u ON a.user_id = u.id
                                    WHERE a.user_id = '$user_id' AND DATE(a.date) = '$today'
                                    ORDER BY a.id DESC LIMIT 5
                                ");
                            } else {
                                $recentLogs = null;
                            }

                            if ($recentLogs && $recentLogs->num_rows > 0):
                                while ($row = $recentLogs->fetch_assoc()): ?>
                                    <div class="dash-act-row">
                                        <div class="dash-act-avatar">
                                            <?= htmlspecialchars(strtoupper(substr($row['name'], 0, 1))) ?>
                                        </div>
                                        <div class="dash-act-main">
                                            <strong><?= htmlspecialchars($row['name']) ?></strong>
                                            <div class="dash-act-meta">
                                                <span><?= htmlspecialchars($row['student_no']) ?></span>
                                                <span>·</span>
                                                <span><?= htmlspecialchars($row['course'] . '-' . $row['section']) ?></span>
                                                <?php if ($row['subject']): ?>
                                                    <span class="subj"><?= htmlspecialchars($row['subject']) ?></span>
                                                <?php endif; ?>
                                                <?php if ($row['instructor_name']): ?>
                                                    <span>·</span>
                                                    <span><i class="bi bi-person-badge"></i>
                                                        <?= htmlspecialchars($row['instructor_name']) ?></span>
                                                <?php endif; ?>
                                            </div>
                                        </div>
                                        <span class="dash-act-time">
                                            <i class="bi bi-clock"></i>
                                            <?= date("g:i A", strtotime($row['time_in'])) ?>
                                        </span>
                                    </div>
                                <?php endwhile;
                            else: ?>
                                <div class="dash-empty">
                                    <i class="bi bi-inbox"></i>
                                    <strong>No activity yet</strong>
                                    <span>Scans will appear here once students take attendance.</span>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="<?= asset('../assets/js/view_attendance.js') ?>"></script>
    <script src="<?= asset('../assets/js/view_absences.js') ?>"></script>
    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>

    <?php if ($trend_ready): ?>
        <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
        <script>
            (function () {
                const canvas = document.getElementById('attendanceTrend');
                if (!canvas || typeof Chart === 'undefined') return;

                const points = <?= json_encode($trend_series, JSON_UNESCAPED_UNICODE) ?>;

                // Kaparehong #667eea ng dashboard. Sinuri laban sa surface
                // na #16161a: pasado sa lightness band, chroma floor, at
                // 3:1 na contrast.
                const SERIES  = '#667eea';
                const SURFACE = '#16161a';
                const GRID    = 'rgba(255,255,255,.06)';
                const INK     = 'rgba(255,255,255,.38)';

                const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

                // The final value gets a direct label — just the one,
                // not every point (that is noisy and unreadable). The
                // axis and tooltip cover the rest.
                const endLabel = {
                    id: 'endLabel',
                    afterDatasetsDraw(chart) {
                        const meta = chart.getDatasetMeta(0);
                        const last = meta.data[meta.data.length - 1];
                        if (!last) return;

                        const value = points[points.length - 1].value;
                        const ctx   = chart.ctx;

                        ctx.save();
                        ctx.font = '600 12px system-ui, -apple-system, "Segoe UI", sans-serif';
                        ctx.fillStyle = 'rgba(255,255,255,.85)';
                        ctx.textAlign = 'right';
                        ctx.textBaseline = 'bottom';
                        ctx.fillText(value.toLocaleString(), last.x + 2, last.y - 12);
                        ctx.restore();
                    }
                };

                new Chart(canvas, {
                    type: 'line',
                    data: {
                        labels: points.map(p => p.label),
                        datasets: [{
                            data: points.map(p => p.value),
                            borderColor: SERIES,
                            // The fill is a wash (~10%), not a solid block.
                            backgroundColor: 'rgba(102,126,234,.10)',
                            fill: true,
                            borderWidth: 2,
                            borderJoinStyle: 'round',
                            borderCapStyle: 'round',
                            tension: .25,
                            pointRadius: 4,
                            pointBackgroundColor: SERIES,
                            // A 2px ring in the surface color keeps the
                            // point legible on top of the line.
                            pointBorderColor: SURFACE,
                            pointBorderWidth: 2,
                            pointHoverRadius: 6,
                            pointHoverBorderWidth: 2,
                            pointHitRadius: 24
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: reduceMotion ? false : { duration: 500 },
                        layout: { padding: { top: 24, right: 14, left: 2, bottom: 2 } },
                        // Only one series — the title above says what it
                        // is, so there is no legend box.
                        plugins: {
                            legend: { display: false },
                            tooltip: {
                                mode: 'index',
                                intersect: false,
                                backgroundColor: '#0f0f13',
                                borderColor: 'rgba(255,255,255,.12)',
                                borderWidth: 1,
                                titleColor: '#f1f5f9',
                                bodyColor: '#cbd5e1',
                                padding: 10,
                                displayColors: false,
                                callbacks: {
                                    title: (items) => points[items[0].dataIndex].full,
                                    label: (item) => ' ' + item.parsed.y.toLocaleString() + ' scanned'
                                }
                            }
                        },
                        interaction: { mode: 'index', intersect: false },
                        scales: {
                            x: {
                                grid: { display: false },
                                border: { color: 'rgba(255,255,255,.1)' },
                                ticks: { color: INK, font: { size: 11 }, maxRotation: 0, autoSkipPadding: 12 }
                            },
                            y: {
                                beginAtZero: true,
                                grid: { color: GRID, drawTicks: false },
                                border: { display: false },
                                ticks: {
                                    color: INK,
                                    font: { size: 11 },
                                    padding: 8,
                                    precision: 0,
                                    maxTicksLimit: 5,
                                    callback: (v) => v.toLocaleString()
                                }
                            }
                        }
                    },
                    plugins: [endLabel]
                });
            })();
        </script>
    <?php endif; ?>
</body>
</html>
