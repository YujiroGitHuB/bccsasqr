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
// ✅ FIXED: CONCAT course + section para maging "BSIT-1A"
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
if ($view_mode === 'sections') {
    if ($role === 'admin') {
        $totalStudent          = $conn->query("SELECT COUNT(DISTINCT student_no) AS total FROM students_tbl WHERE user_id = '$user_id'")->fetch_assoc()['total'];
        // Isang scan na lang ng attendance_tbl para sa dalawang bilang —
        // magkapareho ang WHERE, ang petsa lang ang idinaragdag.
        $m = $conn->query("
            SELECT COUNT(DISTINCT student_no) AS total,
                   COUNT(DISTINCT CASE WHEN DATE(date) = '$selected_date' THEN student_no END) AS present
            FROM attendance_tbl
            WHERE user_id = '$user_id'
        ")->fetch_assoc();
        $totalStudents         = $m['total'];
        $presentOnSelectedDate = $m['present'];
    } elseif ($has_sections) {
        // ✅ FIXED: use full_section in IN clause
        $sections_in           = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $user_sections)) . "'";
        $totalStudent          = $conn->query("SELECT COUNT(DISTINCT student_no) as total FROM students_tbl WHERE CONCAT(course,'-',section) IN ($sections_in)")->fetch_assoc()['total'];
        // ✅ FIXED: attendance_tbl.section stores raw "1A" — use CONCAT to match "BSIT-1A"
        // Pinagsama sa isang scan — magkapareho ang WHERE, petsa lang ang dagdag.
        $m = $conn->query("
            SELECT COUNT(DISTINCT student_no) AS total,
                   COUNT(DISTINCT CASE WHEN DATE(date) = '$selected_date' THEN student_no END) AS present
            FROM attendance_tbl
            WHERE CONCAT(course,'-',section) IN ($sections_in) AND user_id = '$user_id'
        ")->fetch_assoc();
        $totalStudents         = $m['total'];
        $presentOnSelectedDate = $m['present'];
    } else {
        $totalStudent = $totalStudents = $presentOnSelectedDate = 0;
    }
} else {
    if ($has_subjects) {
        $subjects_in           = "'" . implode("','", array_map(fn($s) => $conn->real_escape_string($s), $subject_names)) . "'";
        // Pinagsama sa isang scan — magkapareho ang WHERE, petsa lang ang dagdag.
        $m = $conn->query("
            SELECT COUNT(DISTINCT student_no) AS total,
                   COUNT(DISTINCT CASE WHEN DATE(date) = '$selected_date' THEN student_no END) AS present
            FROM attendance_tbl
            WHERE subject IN ($subjects_in) AND user_id = '$user_id'
        ")->fetch_assoc();
        $totalStudent          = $m['total'];
        $totalStudents         = $totalStudent;
        $presentOnSelectedDate = $m['present'];
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

// ── Helper: matatag na kulay kada section ────────────────────
// Palatandaan lang ito para mabilis makilala ang isang card sa
// mahabang listahan. Ang lumang palette ay may mga pastel (hal.
// #a8edea, #fed6e3) na halos hindi na mabasa ang puting teksto —
// mga tinting na akma sa madilim na background na lang ang natira.
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

    // BATCH 1 — active students + total class days per section
    $b1 = $conn->query("
        SELECT
            CONCAT(course,'-',section) AS section,
            COUNT(DISTINCT student_no)  AS active_students,
            COUNT(DISTINCT DATE(date))  AS total_classes
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

    // BATCH 2a — attended days per student per section
    $attended_map = [];
    $b2a = $conn->query("
        SELECT CONCAT(course,'-',section) AS section, student_no, COUNT(DISTINCT DATE(date)) AS attended
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
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/dashboard.css') ?>">
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
                 Ang ikalawa at ikatlong card ay ratio, kaya isinusulat
                 na rin ang porsyento — ang bar lang dati ang nagsasabi
                 niyon at kailangan pang tantiyahin ng mata. -->
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
                        <span><?= $view_mode === 'subjects' ? 'Sa mga subject mo' : 'Sa mga section mo' ?></span>
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
                        <span>Nakapag-scan kahit minsan</span>
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
                 Dating tatlong kahon ito: "Filter Overview" header,
                 ang date panel, at ang "Currently Viewing" card —
                 pare-parehong sinasabi kung anong petsa ang tinitingnan. -->
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
                                                <span>Walang naka-assign na subject.</span>
                                            </div>
                                        <?php endif; ?>

                                        <!-- Ang tatlong bilang na ito ang laman ng card at hindi na
                                             nakatago sa loob ng collapse — iyon ang unang tinitingnan. -->
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
                                                title="Tingnan at i-export ang listahan">
                                                <i class="bi bi-exclamation-circle-fill"></i>
                                                <span class="n">
                                                    <b><?= number_format($students_3_absences) ?></b>
                                                    <small>3+ absent</small>
                                                </span>
                                            </a>
                                            <a href="#" class="dash-risk crit"
                                                onclick="viewAbsences('<?= htmlspecialchars($section) ?>',5); return false;"
                                                title="Kritikal — tingnan at i-export">
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
                                <span>Wala pang naka-assign na section.</span>
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

                                        <!-- Mapipindot pa rin ang dalawang tile para sa listahan;
                                             ang pang-PDF ay hiwalay na nasa ilalim. -->
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
                                    <span>Wala pang attendance record ang mga subject mo.</span>
                                </div>
                            </div>
                        <?php endif;
                    } else {
                        echo '<div class="col-12"><div class="dash-notice">
                                <i class="bi bi-info-circle-fill"></i>
                                <span>Wala pang naka-assign na subject.</span>
                              </div></div>';
                    }
                }
                ?>
            </div>

            <?php include __DIR__ . "/../components/view_attendance_modal.php"; ?>
            <?php include __DIR__ . "/../components/view_absences_modal.php"; ?>

            <div class="dash-section-title mt-5">
                Recent Activity
                <span class="count">Huling 5 scan ngayong araw</span>
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
                                    <strong>Wala pang aktibidad</strong>
                                    <span>Lilitaw dito ang mga scan pagkatapos mag-attendance ng estudyante.</span>
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
</body>
</html>
