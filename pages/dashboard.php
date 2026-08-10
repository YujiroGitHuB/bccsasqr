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
</head>

<body>
    <?php include __DIR__ . "/../includes/alert.php"; ?>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-3">
            <div>
                <h2>Dashboard</h2>
                <p>Welcome back, <?= $_SESSION['user_name']; ?>!</p>
                <div class="d-flex gap-2 flex-wrap">
                    <?php if ($has_subjects): ?>
                        <div class="info-badge">
                            <i class="bi bi-book-fill text-success"></i>
                            <span class="text-white-50">
                                <strong class="text-white"><?= count($user_subjects) ?></strong>
                                Subject<?= count($user_subjects) > 1 ? 's' : '' ?>
                            </span>
                        </div>
                    <?php endif; ?>
                    <?php if ($has_sections): ?>
                        <div class="info-badge">
                            <i class="bi bi-grid-3x3 text-info"></i>
                            <span class="text-white-50">
                                <strong class="text-white"><?= count($user_sections) ?></strong>
                                Section<?= count($user_sections) > 1 ? 's' : '' ?>
                            </span>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <?php if ($can_switch_view): ?>
                <div class="view-switcher">
                    <a href="?view=sections<?= isset($_GET['filter_date']) ? '&filter_date=' . urlencode($selected_date) : '' ?>"
                        class="view-btn <?= $view_mode === 'sections' ? 'active' : '' ?>">
                        <i class="bi bi-grid-3x3"></i><span>Section Overview</span>
                    </a>
                    <a href="?view=subjects<?= isset($_GET['filter_date']) ? '&filter_date=' . urlencode($selected_date) : '' ?>"
                        class="view-btn <?= $view_mode === 'subjects' ? 'active' : '' ?>">
                        <i class="bi bi-book"></i><span>Subject Details</span>
                    </a>
                </div>
            <?php endif; ?>
        </div>

        <hr class="border-secondary">

        <div class="container-fluid py-4">

            <!-- TOP METRICS HEADER -->
            <div class="section-header mb-4">
                <div class="d-flex align-items-center gap-3">
                    <div class="header-icon-wrapper">
                        <div class="icon-circle">
                            <div class="icon-glow"></div>
                        </div>
                    </div>
                    <div class="metric-card">
                        <h4 class="mb-1 fw-bold text-white">Top Metrics</h4>
                        <p class="mb-0 text-white-50 small">
                            <i class="bi bi-circle-fill text-success me-1" style="font-size:0.5rem;"></i>
                            Live performance overview
                        </p>
                    </div>
                </div>
                <div class="header-decoration"></div>
            </div>

            <div class="row g-4 mb-4">
                <div class="col-md-4">
                    <div class="card bg-dark text-white shadow-lg rounded-4 metric-card border-0 overflow-hidden">
                        <div class="position-absolute top-0 end-0 opacity-25">
                            <i class="bi bi-people-fill" style="font-size:8rem; color:rgba(102,126,234,0.2);"></i>
                        </div>
                        <div class="card-body p-4 position-relative">
                            <div class="d-flex align-items-center mb-3">
                                <div class="icon-box rounded-3 p-3 me-3"
                                    style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
                                    <i class="bi bi-people-fill fs-3 text-white"></i>
                                </div>
                                <div>
                                    <h6 class="text-muted mb-1 fw-normal">
                                        <?= $view_mode === 'subjects' ? 'Unique Students' : 'Total Students' ?>
                                    </h6>
                                    <h2 class="mb-0 fw-bold"><?= number_format($totalStudent) ?></h2>
                                </div>
                            </div>
                            <div class="progress" style="height:4px;">
                                <div class="progress-bar" role="progressbar"
                                    style="width:100%; background:linear-gradient(90deg,#667eea 0%,#764ba2 100%);"></div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="col-md-4">
                    <div class="card bg-dark text-white shadow-lg rounded-4 metric-card border-0 overflow-hidden">
                        <div class="position-absolute top-0 end-0 opacity-25">
                            <i class="bi bi-qr-code-scan" style="font-size:8rem; color:rgba(13,202,240,0.2);"></i>
                        </div>
                        <div class="card-body p-4 position-relative">
                            <div class="d-flex align-items-center mb-3">
                                <div class="icon-box rounded-3 p-3 me-3"
                                    style="background: linear-gradient(135deg, #0dcaf0 0%, #0aa2c0 100%);">
                                    <i class="bi bi-qr-code-scan fs-3 text-white"></i>
                                </div>
                                <div>
                                    <h6 class="text-muted mb-1 fw-normal">Total Scanned</h6>
                                    <h2 class="mb-0 fw-bold"><?= $totalStudents ?></h2>
                                </div>
                            </div>
                            <div class="progress" style="height:4px;">
                                <div class="progress-bar bg-info" role="progressbar"
                                    style="width:<?= $totalStudent > 0 ? ($totalStudents / $totalStudent * 100) : 0 ?>%;"></div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="col-md-4">
                    <div class="card bg-dark text-white shadow-lg rounded-4 metric-card border-0 overflow-hidden">
                        <div class="position-absolute top-0 end-0 opacity-25">
                            <i class="bi bi-person-check-fill" style="font-size:8rem; color:rgba(25,135,84,0.2);"></i>
                        </div>
                        <div class="card-body p-4 position-relative">
                            <div class="d-flex align-items-center mb-3">
                                <div class="icon-box rounded-3 p-3 me-3"
                                    style="background: linear-gradient(135deg, #198754 0%, #146c43 100%);">
                                    <i class="bi bi-person-check-fill fs-3 text-white"></i>
                                </div>
                                <div>
                                    <h6 class="text-muted mb-1 fw-normal">
                                        <?= $selected_date == $today ? 'Present Today' : 'Present on Date' ?>
                                    </h6>
                                    <h2 class="mb-0 fw-bold"><?= $presentOnSelectedDate ?></h2>
                                    <?php if ($selected_date != $today): ?>
                                        <small class="text-muted">
                                            <i class="bi bi-calendar-check"></i>
                                            <?= date('M d', strtotime($selected_date)) ?>
                                        </small>
                                    <?php endif; ?>
                                </div>
                            </div>
                            <div class="progress" style="height:4px;">
                                <div class="progress-bar bg-success" role="progressbar"
                                    style="width:<?= $totalStudents > 0 ? ($presentOnSelectedDate / $totalStudents * 100) : 0 ?>%;"></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- FILTER OVERVIEW HEADER -->
            <div class="section-header mb-4">
                <div class="d-flex align-items-center gap-3">
                    <div class="header-icon-wrapper">
                        <div class="icon-circle"
                            style="background: linear-gradient(135deg, #10b981 0%, #059669 100%);">
                            <div class="icon-glow" style="background: rgba(16,185,129,0.3);"></div>
                        </div>
                    </div>
                    <div class="metric-card">
                        <h4 class="mb-1 fw-bold text-white">Filter Overview</h4>
                        <p class="mb-0 text-white-50 small">
                            <i class="bi bi-calendar3 me-1"></i>Customize your view by date
                        </p>
                    </div>
                </div>
                <div class="header-decoration"
                    style="background: linear-gradient(90deg, transparent, rgba(16,185,129,0.1));"></div>
            </div>

            <!-- Date Filter -->
            <div class="filter-header mb-4">
                <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
                    <div class="header-title">
                        <div class="d-flex align-items-center">
                            <div class="icon-wrapper"><i class="bi bi-clipboard-data"></i></div>
                            <div class="ms-3">
                                <h5 class="text-white mb-0 fw-bold">
                                    <?= $view_mode === 'subjects' ? 'Subject Attendance Details' : 'Section Overview' ?>
                                </h5>
                                <small class="text-white-50">
                                    <?= $view_mode === 'subjects' ? 'Detailed records with export options' : 'Quick overview of all sections' ?>
                                </small>
                            </div>
                        </div>
                    </div>
                    <div class="filter-controls">
                        <form method="GET" action="" class="d-flex align-items-center gap-2" id="dateFilterForm">
                            <?php if (isset($_GET['view'])): ?>
                                <input type="hidden" name="view" value="<?= htmlspecialchars($view_mode) ?>">
                            <?php endif; ?>
                            <div class="date-picker-wrapper">
                                <div class="input-group">
                                    <span class="input-group-text"><i class="bi bi-calendar3"></i></span>
                                    <input type="date" class="form-control"
                                        name="filter_date" id="filter_date"
                                        value="<?= $selected_date ?>" max="<?= $today ?>"
                                        onchange="document.getElementById('dateFilterForm').submit()">
                                </div>
                            </div>
                            <?php if ($selected_date != $today): ?>
                                <button type="button"
                                    onclick="window.location.href='?<?= isset($_GET['view']) ? 'view=' . $view_mode : '' ?>'"
                                    class="btn-today">
                                    <i class="bi bi-arrow-clockwise me-1"></i><span>Today</span>
                                </button>
                            <?php endif; ?>
                        </form>
                    </div>
                </div>
            </div>

            <!-- Selected Date Display -->
            <div class="date-display-card mb-4">
                <div class="card-content">
                    <div class="date-icon"><i class="bi bi-calendar-event"></i></div>
                    <div class="date-info">
                        <span class="label">Currently Viewing</span>
                        <h6 class="date-text"><?= date('l, F d, Y', strtotime($selected_date)) ?></h6>
                    </div>
                    <div class="date-badge">
                        <?php if ($selected_date == $today): ?>
                            <div class="status-badge today">
                                <span class="pulse"></span>
                                <i class="bi bi-clock-fill me-1"></i><span>Live Today</span>
                            </div>
                        <?php else: ?>
                            <div class="status-badge past">
                                <i class="bi bi-archive me-1"></i><span>Historical</span>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
                <div class="card-decoration"></div>
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

                            echo '<div class="col-12 mt-4 mb-3 metric-card">
                                <div class="year-level-header p-3 rounded-4"
                                     style="background:linear-gradient(135deg,rgba(102,126,234,0.1) 0%,rgba(118,75,162,0.1) 100%);
                                            border-left:4px solid #667eea;">
                                  <div class="d-flex align-items-center gap-3"><div>
                                    <h4 class="text-white fw-bold mb-1">' . $year . '</h4>
                                    <p class="text-white-50 mb-0 small"><i class="bi bi-grid-3x3"></i> '
                                . count($secs) . ' Section' . (count($secs) > 1 ? 's' : '') . '</p>
                                  </div></div>
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

                                $colors = [
                                    ['from' => '#667eea', 'to' => '#764ba2'],
                                    ['from' => '#f093fb', 'to' => '#f5576c'],
                                    ['from' => '#4facfe', 'to' => '#00f2fe'],
                                    ['from' => '#43e97b', 'to' => '#38f9d7'],
                                    ['from' => '#fa709a', 'to' => '#fee140'],
                                    ['from' => '#30cfd0', 'to' => '#330867'],
                                    ['from' => '#a8edea', 'to' => '#fed6e3'],
                                    ['from' => '#ff9a9e', 'to' => '#fecfef'],
                                ];
                                $cs = $colors[crc32($section) % count($colors)];
                ?>
                                <div class="col-lg-3 col-md-4 col-sm-6">
                                    <div class="card bg-dark text-white shadow-lg rounded-4 metric-card border-0 overflow-hidden">
                                        <?php if (!$has_subjects): ?>
                                            <div class="alert alert-warning rounded-3 mt-2 mb-0"
                                                style="background:rgba(245,158,11,0.1);border:1px solid rgba(245,158,11,0.3);">
                                                <small class="text-warning">
                                                    <i class="bi bi-info-circle-fill me-1"></i>
                                                    <strong>Note:</strong> No subjects assigned yet.
                                                </small>
                                            </div>
                                        <?php endif; ?>

                                        <div class="card-body p-4 position-relative">
                                            <div class="text-center mb-4 position-relative">
                                                <div class="position-absolute top-50 start-50 translate-middle">
                                                    <div class="pulse-ring"
                                                        style="width:100px;height:100px;border:2px solid <?= $cs['from'] ?>;
                                                            border-radius:50%;opacity:0.3;animation:pulse-ring 2s ease-out infinite;"></div>
                                                </div>
                                                <div class="d-inline-flex align-items-center justify-content-center rounded-circle mb-3 shadow-lg position-relative"
                                                    style="background:linear-gradient(135deg,<?= $cs['from'] ?> 0%,<?= $cs['to'] ?> 100%);
                                                        width:90px;height:90px;animation:float 3s ease-in-out infinite;">
                                                    <i class="bi bi-grid-3x3-gap-fill fs-1 text-white"
                                                        style="filter:drop-shadow(0 2px 4px rgba(0,0,0,0.3));"></i>
                                                </div>
                                                <div class="d-flex align-items-center justify-content-center gap-2 mb-2">
                                                    <span class="badge rounded-pill px-3 py-2 shadow"
                                                        style="background:linear-gradient(135deg,<?= $cs['from'] ?> 0%,<?= $cs['to'] ?> 100%);
                                                             font-size:1rem;letter-spacing:1px;">
                                                        <?= htmlspecialchars($section) ?>
                                                    </span>
                                                </div>
                                                <p class="text-white-50 mb-0 small">
                                                    <i class="bi bi-bar-chart-fill me-1" style="color:<?= $cs['from'] ?>;"></i>
                                                    Overview Statistics (<?= $total_classes ?> classes)
                                                </p>
                                            </div>

                                            <!-- Stats toggle -->
                                            <div class="mb-3">
                                                <button class="btn w-100 text-start p-3 rounded-3 border-0"
                                                    style="background:linear-gradient(135deg,rgba(102,126,234,0.15) 0%,rgba(118,75,162,0.15) 100%);"
                                                    type="button"
                                                    data-bs-toggle="collapse"
                                                    data-bs-target="#stats-<?= htmlspecialchars(str_replace(['-',' '], '_', $section)) ?>"
                                                    aria-expanded="false">
                                                    <div class="d-flex align-items-center justify-content-between">
                                                        <div class="d-flex align-items-center gap-3">
                                                            <div class="rounded-circle p-2"
                                                                style="background:rgba(102,126,234,0.3);">
                                                                <i class="bi bi-bar-chart-fill text-white fs-5"></i>
                                                            </div>
                                                            <div>
                                                                <h6 class="text-white fw-bold mb-1">Section Statistics</h6>
                                                                <div class="row g-2 text-white-50 small">
                                                                    <div class="col-auto">
                                                                        <i class="bi bi-people-fill me-1"></i>
                                                                        <strong class="text-white"><?= number_format($total) ?></strong> Students
                                                                    </div>
                                                                    <div class="col-auto">
                                                                        <i class="bi bi-person-check-fill text-success me-1"></i>
                                                                        <strong class="text-success"><?= number_format($active_students) ?></strong> Active
                                                                    </div>
                                                                    <div class="col-auto">
                                                                        <i class="bi bi-exclamation-triangle-fill text-warning me-1"></i>
                                                                        <strong class="text-warning"><?= number_format($never_attended) ?></strong> Inactive
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>
                                                        <i class="bi bi-chevron-down text-white fs-5"></i>
                                                    </div>
                                                </button>
                                            </div>

                                            <!-- Collapsible details -->
                                            <div class="collapse" id="stats-<?= htmlspecialchars(str_replace(['-',' '], '_', $section)) ?>">
                                                <div class="row g-3 mb-3">
                                                    <div class="col-12">
                                                        <div class="stat-box p-3 rounded-3"
                                                            style="background:rgba(102,126,234,0.1);border-left:3px solid #667eea;">
                                                            <div class="d-flex align-items-center justify-content-between">
                                                                <div>
                                                                    <small class="text-white-50 d-block mb-1">Total Enrolled</small>
                                                                    <h3 class="text-white fw-bold mb-0"><?= number_format($total) ?></h3>
                                                                </div>
                                                                <div class="rounded-circle p-2" style="background:rgba(102,126,234,0.2);">
                                                                    <i class="bi bi-people-fill text-primary fs-4"></i>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="col-12">
                                                        <div class="stat-box p-3 rounded-3"
                                                            style="background:rgba(16,185,129,0.1);border-left:3px solid #10b981;">
                                                            <div class="d-flex align-items-center justify-content-between">
                                                                <div>
                                                                    <small class="text-white-50 d-block mb-1">Active Students</small>
                                                                    <h3 class="text-success fw-bold mb-0"><?= number_format($active_students) ?></h3>
                                                                    <small class="text-success opacity-75">Has attended at least once</small>
                                                                </div>
                                                                <div class="rounded-circle p-2" style="background:rgba(16,185,129,0.2);">
                                                                    <i class="bi bi-person-check-fill text-success fs-4"></i>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="col-12">
                                                        <div class="stat-box p-3 rounded-3"
                                                            style="background:rgba(245,158,11,0.1);border-left:3px solid #f59e0b;">
                                                            <div class="d-flex align-items-center justify-content-between">
                                                                <div>
                                                                    <small class="text-white-50 d-block mb-1">Never Attended</small>
                                                                    <h3 class="text-warning fw-bold mb-0"><?= number_format($never_attended) ?></h3>
                                                                    <small class="text-warning opacity-75">Needs follow-up</small>
                                                                </div>
                                                                <div class="rounded-circle p-2" style="background:rgba(245,158,11,0.2);">
                                                                    <i class="bi bi-exclamation-triangle-fill text-warning fs-4"></i>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="col-12">
                                                        <a href="#" class="text-decoration-none"
                                                            onclick="viewAbsences('<?= htmlspecialchars($section) ?>',3); return false;">
                                                            <div class="stat-box p-3 rounded-3"
                                                                style="background:rgba(239,68,68,0.1);border-left:3px solid #ef4444;">
                                                                <div class="d-flex align-items-center justify-content-between">
                                                                    <div>
                                                                        <small class="text-white-50 d-block mb-1">3+ Absences</small>
                                                                        <h3 class="fw-bold mb-0" style="color:#ef4444;"><?= number_format($students_3_absences) ?></h3>
                                                                        <small style="color:#ef4444;opacity:0.75;">Click to view &amp; export</small>
                                                                    </div>
                                                                    <div class="rounded-circle p-2" style="background:rgba(239,68,68,0.2);">
                                                                        <i class="bi bi-exclamation-circle-fill fs-4" style="color:#ef4444;"></i>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </a>
                                                    </div>
                                                    <div class="col-12">
                                                        <a href="#" class="text-decoration-none"
                                                            onclick="viewAbsences('<?= htmlspecialchars($section) ?>',5); return false;">
                                                            <div class="stat-box p-3 rounded-3"
                                                                style="background:rgba(220,38,38,0.1);border-left:3px solid #dc2626;">
                                                                <div class="d-flex align-items-center justify-content-between">
                                                                    <div>
                                                                        <small class="text-white-50 d-block mb-1">5+ Absences</small>
                                                                        <h3 class="fw-bold mb-0" style="color:#dc2626;"><?= number_format($students_5_absences) ?></h3>
                                                                        <small style="color:#dc2626;opacity:0.75;">Critical — Click to view &amp; export</small>
                                                                    </div>
                                                                    <div class="rounded-circle p-2" style="background:rgba(220,38,38,0.2);">
                                                                        <i class="bi bi-x-octagon-fill fs-4" style="color:#dc2626;"></i>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </a>
                                                    </div>
                                                    <div class="col-12">
                                                        <div class="stat-box p-3 rounded-3"
                                                            style="background:rgba(13,202,240,0.1);border-left:3px solid #0dcaf0;">
                                                            <div class="d-flex align-items-center justify-content-between">
                                                                <div>
                                                                    <small class="text-white-50 d-block mb-1">Engagement Rate</small>
                                                                    <h3 class="text-info fw-bold mb-0"><?= $engagement_rate ?>%</h3>
                                                                </div>
                                                                <div class="rounded-circle p-2" style="background:rgba(13,202,240,0.2);">
                                                                    <i class="bi bi-graph-up-arrow text-info fs-4"></i>
                                                                </div>
                                                            </div>
                                                            <div class="progress mt-2" style="height:6px;background:rgba(255,255,255,0.1);">
                                                                <div class="progress-bar bg-info" role="progressbar"
                                                                    style="width:<?= $engagement_rate ?>%"
                                                                    aria-valuenow="<?= $engagement_rate ?>"
                                                                    aria-valuemin="0" aria-valuemax="100"></div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>

                                            <div class="info-note p-2 rounded-3 text-center"
                                                style="background:rgba(102,126,234,0.05);border:1px dashed rgba(102,126,234,0.3);">
                                                <small class="text-white-50">
                                                    <i class="bi bi-info-circle me-1"></i>
                                                    Click absences stats to view details and export PDF
                                                </small>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <?php
                            endforeach;
                        }
                    } else {
                        echo '<div class="col-12"><div class="alert alert-info rounded-4 border-0">
                              <i class="bi bi-info-circle me-2"></i> No sections assigned yet.
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
                                    <div class="col-12 mt-4 mb-3">
                                        <div class="p-3 rounded-4"
                                            style="background:linear-gradient(135deg,rgba(102,126,234,0.1) 0%,rgba(118,75,162,0.1) 100%);
                                                border-left:4px solid #667eea;">
                                            <h4 class="text-white fw-bold mb-0">
                                                <i class="bi bi-mortarboard-fill me-2" style="color:#667eea;"></i><?= $yr ?>
                                            </h4>
                                        </div>
                                    </div>
                                <?php endif; ?>

                                <?php if ($current_subject !== $subject): $current_subject = $subject; ?>
                                    <div class="col-12 mb-2 ps-2">
                                        <div class="p-2 px-3 rounded-3 d-flex align-items-center gap-2"
                                            style="background:rgba(16,185,129,0.08);border-left:3px solid #10b981;">
                                            <i class="bi bi-book-fill" style="color:#10b981;"></i>
                                            <span class="text-white fw-semibold"><?= htmlspecialchars($subject) ?></span>
                                        </div>
                                    </div>
                                <?php endif; ?>

                                <div class="col-md-4">
                                    <div class="card bg-dark text-white shadow-lg rounded-4 section-card p-3 border-0 h-100">
                                        <div class="card-body">
                                            <div class="mb-3 text-center">
                                                <div class="d-inline-block p-3 rounded-circle"
                                                    style="background:linear-gradient(135deg,#10b981 0%,#059669 100%);">
                                                    <i class="bi bi-book-fill fs-3 text-white"></i>
                                                </div>
                                            </div>
                                            <h6 class="text-white fw-bold mb-1">
                                                <?= htmlspecialchars($subject) ?> - <?= htmlspecialchars($section) ?>
                                            </h6>
                                            <p class="text-white-50 small mb-3">
                                                <i class="bi bi-person-fill"></i> <?= $total_students ?> Students
                                            </p>

                                            <div class="row g-2 mb-3">
                                                <div class="col-6">
                                                    <a href="#" class="text-decoration-none"
                                                        onclick="viewAttendance('<?= htmlspecialchars($subject) ?>','<?= htmlspecialchars($section) ?>','present','<?= $selected_date ?>'); return false;">
                                                        <div class="card bg-success bg-opacity-10 border-0 rounded-3 p-2 hover-lift" style="cursor:pointer;">
                                                            <div class="text-center">
                                                                <i class="bi bi-check-circle-fill text-success fs-4"></i>
                                                                <h4 class="fw-bold text-white mb-0 mt-2"><?= $present_on_date ?></h4>
                                                                <small class="text-success fw-semibold">Present</small>
                                                            </div>
                                                        </div>
                                                    </a>
                                                </div>
                                                <div class="col-6">
                                                    <a href="#" class="text-decoration-none"
                                                        onclick="viewAttendance('<?= htmlspecialchars($subject) ?>','<?= htmlspecialchars($section) ?>','absent','<?= $selected_date ?>'); return false;">
                                                        <div class="card bg-danger bg-opacity-10 border-0 rounded-3 p-2 hover-lift" style="cursor:pointer;">
                                                            <div class="text-center">
                                                                <i class="bi bi-x-circle-fill text-danger fs-4"></i>
                                                                <h4 class="fw-bold text-white mb-0 mt-2"><?= $absent_on_date ?></h4>
                                                                <small class="text-danger fw-semibold">Absent</small>
                                                            </div>
                                                        </div>
                                                    </a>
                                                </div>
                                            </div>

                                            <div class="row g-2">
                                                <div class="col-6">
                                                    <form action="../exports/export_pdf.php" method="POST">
                                                        <input type="hidden" name="subject" value="<?= htmlspecialchars($subject) ?>">
                                                        <input type="hidden" name="section" value="<?= htmlspecialchars($section) ?>">
                                                        <input type="hidden" name="status" value="present">
                                                        <input type="hidden" name="date" value="<?= $selected_date ?>">
                                                        <button type="submit" class="btn btn-success btn-sm w-100 rounded-pill">
                                                            <i class="bi bi-file-earmark-pdf"></i> Present
                                                        </button>
                                                    </form>
                                                </div>
                                                <div class="col-6">
                                                    <form action="../exports/export_pdf.php" method="POST">
                                                        <input type="hidden" name="subject" value="<?= htmlspecialchars($subject) ?>">
                                                        <input type="hidden" name="section" value="<?= htmlspecialchars($section) ?>">
                                                        <input type="hidden" name="status" value="absent">
                                                        <input type="hidden" name="date" value="<?= $selected_date ?>">
                                                        <button type="submit" class="btn btn-danger btn-sm w-100 rounded-pill">
                                                            <i class="bi bi-file-earmark-pdf"></i> Absent
                                                        </button>
                                                    </form>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            <?php
                            endwhile;
                        else: ?>
                            <div class="col-12">
                                <div class="alert alert-info rounded-4 border-0">
                                    <i class="bi bi-info-circle me-2"></i>
                                    No attendance records found for your subjects yet.
                                </div>
                            </div>
                        <?php endif;
                    } else {
                        echo '<div class="col-12"><div class="alert alert-info rounded-4 border-0">
                              <i class="bi bi-info-circle me-2"></i> No subjects assigned yet.
                          </div></div>';
                    }
                }
                ?>
            </div>

            <?php include __DIR__ . "/../components/view_attendance_modal.php"; ?>
            <?php include __DIR__ . "/../components/view_absences_modal.php"; ?>

            <hr class="border-secondary">

            <!-- RECENT ACTIVITY -->
            <div class="section-header mb-4">
                <div class="d-flex align-items-center justify-content-between flex-wrap gap-3 metric-card">
                    <div class="d-flex align-items-center gap-3">
                        <div>
                            <h4 class="mb-1 fw-bold text-white">Recent Activity</h4>
                            <p class="mb-0 text-white-50 small">
                                <i class="bi bi-arrow-repeat me-1"></i>Latest attendance records
                            </p>
                        </div>
                    </div>
                    <span class="badge bg-success bg-opacity-25 text-success rounded-pill px-3 py-2">
                        <i class="bi bi-circle-fill" style="font-size:0.5rem;animation:pulse-dot 2s ease-in-out infinite;"></i>
                        Live Updates
                    </span>
                </div>
                <div class="header-decoration"
                    style="background:linear-gradient(90deg,transparent,rgba(13,202,240,0.1));"></div>
            </div>

            <div class="row g-3">
                <div class="col-12">
                    <div class="card bg-dark text-white shadow-lg rounded-4 metric-card border-0 overflow-hidden">
                        <div class="card-body p-4">
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
                                    <div class="activity-item mb-3 p-3 rounded" style="background:#1e293b;">
                                        <div class="row align-items-center">
                                            <div class="col-auto">
                                                <div class="rounded-circle p-2"
                                                    style="background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);">
                                                    <i class="bi bi-person-fill text-white"></i>
                                                </div>
                                            </div>
                                            <div class="col">
                                                <h6 class="mb-1 text-white"><?= htmlspecialchars($row['name']) ?></h6>
                                                <small class="text-muted d-block">
                                                    <?= htmlspecialchars($row['student_no']) ?> |
                                                    <?= htmlspecialchars($row['section']) ?>
                                                    <?php if ($row['subject']): ?>
                                                        | <span class="badge"
                                                            style="background:linear-gradient(135deg,#10b981 0%,#059669 100%);">
                                                            <?= htmlspecialchars($row['subject']) ?>
                                                        </span>
                                                    <?php endif; ?>
                                                </small>
                                                <?php if ($row['instructor_name']): ?>
                                                    <small class="text-white-50 d-block mt-1">
                                                        <i class="bi bi-person-badge text-info"></i>
                                                        Scanned by: <span class="text-info fw-semibold">
                                                            <?= htmlspecialchars($row['instructor_name']) ?>
                                                        </span>
                                                    </small>
                                                <?php endif; ?>
                                            </div>
                                            <div class="col-auto">
                                                <span class="badge bg-success">
                                                    <i class="bi bi-clock-fill me-1"></i>
                                                    <?= date("g:i A", strtotime($row['time_in'])) ?>
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                <?php endwhile;
                            else: ?>
                                <div class="empty-state text-center py-5">
                                    <div class="empty-icon mb-3">
                                        <i class="bi bi-inbox"></i>
                                        <div class="empty-icon-circle"></div>
                                    </div>
                                    <h6 class="text-white mb-2">No Activity Yet</h6>
                                    <p class="text-muted mb-0">
                                        Activities will appear here when students scan their QR codes
                                    </p>
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