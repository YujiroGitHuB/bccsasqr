<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/enrollment_scope.php";

$user_role = $_SESSION['role'] ?? 'instructor';
$user_id   = $_SESSION['user_id'] ?? 0;

if (!in_array($user_role, ['admin', 'instructor'])) {
    header("Location: dashboard.php");
    exit;
}

requirePermission('enrollment.manage');

$systemQuery   = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system        = mysqli_fetch_assoc($systemQuery);
$systemName    = $system['system_name']    ?? '';
$systemAcronym = $system['system_acronym'] ?? '';
$systemLogo    = $system['logo']           ?? '';

// Sections and the section scope both come from
// includes/enrollment_scope.php — an admin sees every section, an
// instructor only their own, and that rule is written once there
// because this page and get_enrollment_data_ajax.php must agree on
// it exactly.
$sections = enrollment_scope_sections($conn, $user_role, $user_id);

// Subjects: the whole catalogue for an admin, only what they teach
// for an instructor. Small either way, so it stays server-rendered.
if ($user_role === 'admin') {
    $subjects_query = $conn->query("
        SELECT subject_code, subject_name
        FROM subjects_tbl
        ORDER BY subject_name
    ");
    $subjects = $subjects_query ? $subjects_query->fetch_all(MYSQLI_ASSOC) : [];
} else {
    $subj_q = $conn->prepare("
        SELECT s.subject_code, s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON si.subject_id = s.id
        WHERE si.instructor_id = ?
        ORDER BY s.subject_name
    ");
    $subj_q->bind_param("i", $user_id);
    $subj_q->execute();
    $subjects = $subj_q->get_result()->fetch_all(MYSQLI_ASSOC);
    $subj_q->close();
}

// The enrollments and the student list are NOT loaded here any more.
// Both used to be rendered into the page in full — 1,586 table rows
// and every student in the school, about 4.4 MB of markup before the
// first five rows could appear. They arrive as JSON from
// pages/get_enrollment_data_ajax.php instead.
//
// Only the total is still counted server-side, so the two badges are
// right in the first paint instead of jumping when the rows land. The
// joins have to match the endpoint's, or the badge would promise rows
// the table never shows.
$countWhere = enrollment_scope_where($conn, $user_role, $sections, 'st.course', 'ss.section');
$countResult = $conn->query("
    SELECT COUNT(*) AS total
    FROM student_subjects_tbl ss
    INNER JOIN students_tbl  st  ON st.student_no    = ss.student_no
    INNER JOIN subjects_tbl  sub ON sub.subject_code = ss.subject_code
    WHERE $countWhere
");
$enrollmentCount = $countResult ? (int) $countResult->fetch_assoc()['total'] : 0;
?>

<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/academic-pages.css') ?>">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
    <style>
        .enroll-tabs { display:flex; gap:4px; margin-bottom:20px; background:rgba(0,0,0,.25); padding:4px; border-radius:8px; }
        .enroll-tab-btn { flex:1; padding:8px; background:transparent; border:none; color:#adb5bd; border-radius:6px; cursor:pointer; font-size:0.85rem; font-weight:600; transition:all 0.2s; }
        .enroll-tab-btn.active { background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); color:#fff; }
        .enroll-tab-content { display:none; }
        .enroll-tab-content.active { display:block; }
        tr.row-selected td { background:rgba(102,126,234,0.1) !important; border-color:rgba(102,126,234,0.3); }
        select optgroup { color:#94a3b8; font-style:normal; font-size:.78rem; }
        select option { color:#fff; }
        .searchable-dropdown { position:relative; }
        .sd-trigger { width:100%; background:rgba(255,255,255,.05); border:1px solid rgba(255,255,255,.1); border-radius:8px; padding:.75rem 1rem; color:#fff; cursor:pointer; text-align:left; font-size:.9rem; transition:all .3s; display:flex; align-items:center; justify-content:space-between; gap:.5rem; }
        .sd-trigger:focus,.sd-trigger.open { border-color:#667eea; box-shadow:0 0 0 .2rem rgba(102,126,234,.25); background:rgba(255,255,255,.08); outline:none; }
        .sd-trigger .sd-trigger-text { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        .sd-trigger .sd-trigger-text.sd-placeholder { color:#6c757d; }
        .sd-trigger .sd-arrow { flex-shrink:0; color:#6c757d; transition:transform .2s; }
        .sd-trigger.open .sd-arrow { transform:rotate(180deg); }
        .sd-panel { display:none; position:absolute; top:calc(100% + 4px); left:0; right:0; background:#1a1a2e; border:1px solid rgba(102,126,234,.4); border-radius:10px; z-index:9999; box-shadow:0 8px 30px rgba(0,0,0,.5); overflow:hidden; animation:sdFade .15s ease; }
        @keyframes sdFade { from{opacity:0;transform:translateY(-6px)} to{opacity:1;transform:translateY(0)} }
        .sd-panel.open { display:block; }
        .sd-search-wrap { padding:10px; border-bottom:1px solid rgba(255,255,255,.08); background:#1a1a2e; position:relative; }
        .sd-search-wrap i { position:absolute; left:20px; top:50%; transform:translateY(-50%); color:#6c757d; font-size:.85rem; pointer-events:none; }
        .sd-search-wrap input { width:100%; background:rgba(255,255,255,.07); border:1px solid rgba(255,255,255,.15); border-radius:6px; padding:7px 10px 7px 32px; color:#fff; font-size:.85rem; outline:none; transition:border-color .2s; }
        .sd-search-wrap input:focus { border-color:#667eea; }
        .sd-search-wrap input::placeholder { color:#6c757d; }
        .sd-list { max-height:220px; overflow-y:auto; }
        .sd-list::-webkit-scrollbar { width:5px; }
        .sd-list::-webkit-scrollbar-track { background:#0f172a; }
        .sd-list::-webkit-scrollbar-thumb { background:#667eea; border-radius:10px; }
        .sd-group { font-size:.7rem; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#667eea; padding:7px 12px 4px; background:rgba(102,126,234,.08); border-top:1px solid rgba(102,126,234,.15); }
        .sd-group:first-child { border-top:none; }
        .sd-item { padding:8px 14px; font-size:.87rem; color:#e2e8f0; cursor:pointer; display:flex; align-items:center; gap:8px; transition:background .12s; }
        .sd-item:hover,.sd-item.focused { background:rgba(102,126,234,.2); color:#fff; }
        .sd-item.selected { background:rgba(102,126,234,.3); color:#fff; font-weight:600; }
        .sd-sec-badge { font-size:.68rem; padding:2px 6px; border-radius:4px; background:rgba(102,126,234,.3); color:#a5b4fc; flex-shrink:0; }
        .sd-stuno { font-size:.73rem; color:#64748b; margin-left:auto; }
        .sd-empty { padding:20px; text-align:center; color:#64748b; font-size:.85rem; }
        .sd-empty i { display:block; font-size:1.5rem; margin-bottom:6px; opacity:.4; }
        .sd-course-pill { font-size:.68rem; font-weight:700; padding:2px 7px; border-radius:4px; background:rgba(118,75,162,.35); color:#d8b4fe; flex-shrink:0; letter-spacing:.3px; }

        /* ─── Skeleton Loading ─────────────────────────────────────────── */
        @keyframes skeletonShimmer {
            0%   { background-position: -600px 0; }
            100% { background-position:  600px 0; }
        }

        .skeleton-bar {
            display: inline-block;
            border-radius: 5px;
            background: linear-gradient(
                90deg,
                rgba(255,255,255,.04) 25%,
                rgba(102,126,234,.18) 50%,
                rgba(255,255,255,.04) 75%
            );
            background-size: 600px 100%;
            animation: skeletonShimmer 1.6s infinite linear;
        }

        .skeleton-circle {
            width: 20px;
            height: 20px;
            border-radius: 5px;
        }

        #enrollTableSkeleton {
            width: 100%;
            table-layout: fixed;
        }

        #enrollTableSkeleton thead th {
            padding: 12px 14px;
            font-size: .8rem;
            color: #4a5568;
            border-bottom: 1px solid rgba(255,255,255,.07);
            white-space: nowrap;
        }

        .skeleton-row td {
            padding: 13px 14px;
            border-bottom: 1px solid rgba(255,255,255,.04);
            vertical-align: middle;
        }

        .skeleton-row:last-child td {
            border-bottom: none;
        }

        /* Pulse glow on the row during load */
        .skeleton-row {
            animation: skeletonRowFade 2s ease-in-out infinite;
        }
        .skeleton-row:nth-child(even) { animation-delay: .15s; }
        .skeleton-row:nth-child(3n)   { animation-delay: .3s; }
        .skeleton-row:nth-child(4n)   { animation-delay: .45s; }
        .skeleton-row:nth-child(5n)   { animation-delay: .6s; }

        @keyframes skeletonRowFade {
            0%,100% { opacity: .7; }
            50%      { opacity: 1;  }
        }

        /* Wrapper that fades out */
        #skeletonWrapper {
            transition: opacity .35s ease, transform .35s ease;
        }
        #skeletonWrapper.hiding {
            opacity: 0;
            transform: translateY(-4px);
            pointer-events: none;
        }

        /* Real table fades in — controlled via inline styles in JS */
        #realTableWrapper {
            transition: opacity .35s ease;
        }
    </style>
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content acad-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="acad-hero">
            <div class="acad-hero-icon"><i class="bi bi-book-half"></i></div>
            <div class="acad-hero-text">
                <h2>Subject Enrollment</h2>
                <p>Which subjects each student is taking — the scanner checks this on every attendance.</p>
            </div>
            <div class="acad-hero-meta">
                <span class="acad-chip">
                    <i class="bi bi-list-check"></i> <span id="enrollCount"><?= $enrollmentCount ?></span> enrolled
                </span>
                <span class="acad-chip cyan">
                    <i class="bi bi-grid-3x3-gap"></i> <?= count($sections) ?> sections
                </span>
                <?php if ($user_role === 'admin'): ?>
                    <span class="acad-chip"><i class="bi bi-shield-check"></i> Admin — All Sections</span>
                <?php else: ?>
                    <span class="acad-chip green"><i class="bi bi-person-check"></i> Instructor — My Sections Only</span>
                <?php endif; ?>
            </div>
        </div>

        <div class="row g-4">

            <!-- LEFT: Assignment Form -->
            <div class="col-xl-4 col-lg-5">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-plus-circle-fill"></i>
                        <h4>Assign Subject</h4>
                    </div>

                    <div id="leftRealWrapper">
                    <div class="enroll-tabs">
                        <button class="enroll-tab-btn active" onclick="switchEnrollTab('individual', this)">
                            <i class="bi bi-person me-1"></i>Individual
                        </button>
                        <button class="enroll-tab-btn" onclick="switchEnrollTab('bulk', this)">
                            <i class="bi bi-people me-1"></i>Bulk by Section
                        </button>
                    </div>

                    <!-- Individual Tab -->
                    <div id="enroll-tab-individual" class="enroll-tab-content active">
                        <div class="alert alert-info d-flex gap-2 py-2 mb-3" style="font-size:.82rem;">
                            <i class="bi bi-info-circle-fill mt-1"></i>
                            <span>Assign a specific subject to a single student.</span>
                        </div>

                        <div class="mb-3">
                            <label class="form-label"><i class="bi bi-funnel"></i>Filter by Section</label>
                            <input type="hidden" id="filterSection" value="">
                            <div class="searchable-dropdown" id="sd-wrap-filterSection">
                                <button type="button" class="sd-trigger" id="sd-btn-filterSection" onclick="sdToggle('filterSection')">
                                    <span class="sd-trigger-text sd-placeholder" id="sd-txt-filterSection">-- All Sections --</span>
                                    <i class="bi bi-chevron-down sd-arrow"></i>
                                </button>
                                <div class="sd-panel" id="sd-panel-filterSection">
                                    <div class="sd-search-wrap">
                                        <i class="bi bi-search"></i>
                                        <input type="text" placeholder="Search section..."
                                            oninput="sdFilter('filterSection',this.value)"
                                            onkeydown="sdKeydown(event,'filterSection')">
                                    </div>
                                    <div class="sd-list" id="sd-list-filterSection">
                                        <div class="sd-item" data-value="" data-label="All Sections"
                                            onclick="sdSelect('filterSection','','All Sections',this,true)">
                                            <i class="bi bi-grid me-1" style="color:#6c757d"></i> All Sections
                                        </div>
                                        <?php
                                        $grouped = [];
                                        foreach ($sections as $sec) { $grouped[$sec['course']][] = $sec; }
                                        foreach ($grouped as $course => $secs):
                                        ?>
                                        <div class="sd-group" data-group="<?= htmlspecialchars($course) ?>">
                                            <i class="bi bi-mortarboard me-1"></i><?= htmlspecialchars($course) ?>
                                        </div>
                                        <?php foreach ($secs as $sec): ?>
                                        <div class="sd-item"
                                            data-value="<?= htmlspecialchars($sec['full_section']) ?>"
                                            data-label="<?= htmlspecialchars($sec['full_section']) ?>"
                                            data-group="<?= htmlspecialchars($course) ?>"
                                            onclick="sdSelect('filterSection','<?= htmlspecialchars($sec['full_section']) ?>','<?= htmlspecialchars($sec['full_section']) ?>',this);filterEnrollStudents()">
                                            <span class="sd-sec-badge"><?= htmlspecialchars($sec['full_section']) ?></span>
                                        </div>
                                        <?php endforeach; endforeach; ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="mb-3">
                            <label class="form-label"><i class="bi bi-person-badge"></i>Select Student *</label>
                            <input type="hidden" id="enrollStudentSelect" value="">
                            <div class="searchable-dropdown" id="studentDropdown">
                                <button type="button" class="sd-trigger" id="studentTrigger" onclick="toggleStudentDropdown()">
                                    <span class="sd-trigger-text sd-placeholder" id="studentTriggerText">-- Select Student --</span>
                                    <i class="bi bi-chevron-down sd-arrow"></i>
                                </button>
                                <div class="sd-panel" id="studentPanel">
                                    <div class="sd-search-wrap">
                                        <i class="bi bi-search"></i>
                                        <input type="text" id="studentSearch"
                                            placeholder="Search by name or student no..."
                                            oninput="filterStudentList(this.value)"
                                            onkeydown="studentSearchKeydown(event)">
                                    </div>
                                    <div class="sd-list" id="studentList">
                                        <?php // Filled in by assets/js/subject_enrollment.js from
                                              // get_enrollment_data_ajax.php, and only with the
                                              // students the search actually matches. Every student
                                              // in the school used to be written out here. ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="mb-3">
                            <label class="form-label"><i class="bi bi-book"></i>Select Subject *</label>
                            <input type="hidden" id="enrollSubjectSelect" value="">
                            <div class="searchable-dropdown" id="sd-wrap-enrollSubjectSelect">
                                <button type="button" class="sd-trigger" id="sd-btn-enrollSubjectSelect" onclick="sdToggle('enrollSubjectSelect')">
                                    <span class="sd-trigger-text sd-placeholder" id="sd-txt-enrollSubjectSelect">-- Select Subject --</span>
                                    <i class="bi bi-chevron-down sd-arrow"></i>
                                </button>
                                <div class="sd-panel" id="sd-panel-enrollSubjectSelect">
                                    <div class="sd-search-wrap">
                                        <i class="bi bi-search"></i>
                                        <input type="text" placeholder="Search subject name or code..."
                                            oninput="sdFilter('enrollSubjectSelect',this.value)"
                                            onkeydown="sdKeydown(event,'enrollSubjectSelect')">
                                    </div>
                                    <div class="sd-list" id="sd-list-enrollSubjectSelect">
                                        <?php foreach ($subjects as $sub): ?>
                                        <div class="sd-item"
                                            data-value="<?= htmlspecialchars($sub['subject_code']) ?>"
                                            data-label="<?= htmlspecialchars($sub['subject_name']) ?>"
                                            data-search="<?= strtolower(htmlspecialchars($sub['subject_name'].' '.$sub['subject_code'])) ?>"
                                            onclick="sdSelect('enrollSubjectSelect','<?= htmlspecialchars($sub['subject_code'],ENT_QUOTES) ?>','<?= htmlspecialchars($sub['subject_name'],ENT_QUOTES) ?>',this)">
                                            <span><?= htmlspecialchars($sub['subject_name']) ?></span>
                                            <span class="sd-stuno"><?= htmlspecialchars($sub['subject_code']) ?></span>
                                        </div>
                                        <?php endforeach; ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="mb-4">
                            <label class="form-label"><i class="bi bi-layers"></i>Section for this Subject *</label>
                            <input type="hidden" id="enrollSectionSelect" value="">
                            <input type="hidden" id="enrollCourseSelect"  value="">
                            <div class="searchable-dropdown" id="sd-wrap-enrollSectionSelect">
                                <button type="button" class="sd-trigger" id="sd-btn-enrollSectionSelect" onclick="sdToggle('enrollSectionSelect')">
                                    <span class="sd-trigger-text sd-placeholder" id="sd-txt-enrollSectionSelect">-- Select Section --</span>
                                    <i class="bi bi-chevron-down sd-arrow"></i>
                                </button>
                                <div class="sd-panel" id="sd-panel-enrollSectionSelect">
                                    <div class="sd-search-wrap">
                                        <i class="bi bi-search"></i>
                                        <input type="text" placeholder="Search section..."
                                            oninput="sdFilter('enrollSectionSelect',this.value)"
                                            onkeydown="sdKeydown(event,'enrollSectionSelect')">
                                    </div>
                                    <div class="sd-list" id="sd-list-enrollSectionSelect">
                                        <?php foreach ($grouped as $course => $secs): ?>
                                        <div class="sd-group" data-group="<?= htmlspecialchars($course) ?>">
                                            <i class="bi bi-mortarboard me-1"></i><?= htmlspecialchars($course) ?>
                                        </div>
                                        <?php foreach ($secs as $sec): ?>
                                        <div class="sd-item"
                                            data-value="<?= htmlspecialchars($sec['section']) ?>"
                                            data-course="<?= htmlspecialchars($course) ?>"
                                            data-full="<?= htmlspecialchars($sec['full_section']) ?>"
                                            data-label="<?= htmlspecialchars($sec['full_section']) ?>"
                                            data-group="<?= htmlspecialchars($course) ?>"
                                            onclick="sdSelectSection('enrollSectionSelect','enrollCourseSelect',
                                                '<?= htmlspecialchars($sec['section']) ?>',
                                                '<?= htmlspecialchars($course) ?>',
                                                '<?= htmlspecialchars($sec['full_section']) ?>',this)">
                                            <span class="sd-course-pill"><?= htmlspecialchars($course) ?></span>
                                            <span class="sd-sec-badge"><?= htmlspecialchars($sec['section']) ?></span>
                                        </div>
                                        <?php endforeach; endforeach; ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <button class="btn btn-primary w-100" onclick="assignIndividual()">
                            <i class="bi bi-plus-circle me-1"></i>Assign Subject
                        </button>
                    </div>

                    <!-- Bulk Tab -->
                    <div id="enroll-tab-bulk" class="enroll-tab-content">
                        <div class="alert alert-info d-flex gap-2 py-2 mb-3" style="font-size:.82rem;">
                            <i class="bi bi-info-circle-fill mt-1"></i>
                            <span>Assign one subject to ALL students in a section at once.</span>
                        </div>

                        <div class="mb-3">
                            <label class="form-label"><i class="bi bi-layers"></i>Select Section *</label>
                            <input type="hidden" id="bulkSection"       value="">
                            <input type="hidden" id="bulkSectionCourse" value="">
                            <div class="searchable-dropdown" id="sd-wrap-bulkSection">
                                <button type="button" class="sd-trigger" id="sd-btn-bulkSection" onclick="sdToggle('bulkSection')">
                                    <span class="sd-trigger-text sd-placeholder" id="sd-txt-bulkSection">-- Select Section --</span>
                                    <i class="bi bi-chevron-down sd-arrow"></i>
                                </button>
                                <div class="sd-panel" id="sd-panel-bulkSection">
                                    <div class="sd-search-wrap">
                                        <i class="bi bi-search"></i>
                                        <input type="text" placeholder="Search section..."
                                            oninput="sdFilter('bulkSection',this.value)"
                                            onkeydown="sdKeydown(event,'bulkSection')">
                                    </div>
                                    <div class="sd-list" id="sd-list-bulkSection">
                                        <?php foreach ($grouped as $course => $secs): ?>
                                        <div class="sd-group" data-group="<?= htmlspecialchars($course) ?>">
                                            <i class="bi bi-mortarboard me-1"></i><?= htmlspecialchars($course) ?>
                                        </div>
                                        <?php foreach ($secs as $sec): ?>
                                        <div class="sd-item"
                                            data-value="<?= htmlspecialchars($sec['section']) ?>"
                                            data-course="<?= htmlspecialchars($course) ?>"
                                            data-full="<?= htmlspecialchars($sec['full_section']) ?>"
                                            data-label="<?= htmlspecialchars($sec['full_section']) ?>"
                                            data-group="<?= htmlspecialchars($course) ?>"
                                            onclick="sdSelectSection('bulkSection','bulkSectionCourse',
                                                '<?= htmlspecialchars($sec['section']) ?>',
                                                '<?= htmlspecialchars($course) ?>',
                                                '<?= htmlspecialchars($sec['full_section']) ?>',this)">
                                            <span class="sd-course-pill"><?= htmlspecialchars($course) ?></span>
                                            <span class="sd-sec-badge"><?= htmlspecialchars($sec['section']) ?></span>
                                        </div>
                                        <?php endforeach; endforeach; ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="mb-4">
                            <label class="form-label"><i class="bi bi-book"></i>Select Subject *</label>
                            <input type="hidden" id="bulkSubject" value="">
                            <div class="searchable-dropdown" id="sd-wrap-bulkSubject">
                                <button type="button" class="sd-trigger" id="sd-btn-bulkSubject" onclick="sdToggle('bulkSubject')">
                                    <span class="sd-trigger-text sd-placeholder" id="sd-txt-bulkSubject">-- Select Subject --</span>
                                    <i class="bi bi-chevron-down sd-arrow"></i>
                                </button>
                                <div class="sd-panel" id="sd-panel-bulkSubject">
                                    <div class="sd-search-wrap">
                                        <i class="bi bi-search"></i>
                                        <input type="text" placeholder="Search subject name or code..."
                                            oninput="sdFilter('bulkSubject',this.value)"
                                            onkeydown="sdKeydown(event,'bulkSubject')">
                                    </div>
                                    <div class="sd-list" id="sd-list-bulkSubject">
                                        <?php foreach ($subjects as $sub): ?>
                                        <div class="sd-item"
                                            data-value="<?= htmlspecialchars($sub['subject_code']) ?>"
                                            data-label="<?= htmlspecialchars($sub['subject_name']) ?>"
                                            data-search="<?= strtolower(htmlspecialchars($sub['subject_name'].' '.$sub['subject_code'])) ?>"
                                            onclick="sdSelect('bulkSubject','<?= htmlspecialchars($sub['subject_code'],ENT_QUOTES) ?>','<?= htmlspecialchars($sub['subject_name'],ENT_QUOTES) ?>',this)">
                                            <span><?= htmlspecialchars($sub['subject_name']) ?></span>
                                            <span class="sd-stuno"><?= htmlspecialchars($sub['subject_code']) ?></span>
                                        </div>
                                        <?php endforeach; ?>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <hr style="border-color:rgba(255,255,255,.1);">
                        <button class="btn btn-primary w-100" onclick="assignBulk()">
                            <i class="bi bi-lightning-charge me-1"></i>Bulk Assign to Section
                        </button>
                    </div>
                    </div>
                </div>
            </div>

            <!-- RIGHT: Enrollment Table -->
            <div class="col-xl-8 col-lg-7">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-list-check"></i>
                        <h4>Current Enrollments</h4>
                        <span class="badge-count ms-auto" id="tableCount"><?= $enrollmentCount ?></span>
                    </div>

                    <div id="bulkActionBar" class="bulk-action-bar mb-3 rounded" style="display:none;">
                        <div class="bulk-action-content">
                            <div class="bulk-selected-count">
                                <i class="bi bi-check2-square"></i>
                                <span id="selectedCount">0</span> row(s) selected
                            </div>
                            <button class="btn btn-sm btn-danger ms-auto" onclick="deleteSelected()">
                                <i class="bi bi-trash me-1"></i>Delete Selected
                            </button>
                            <button class="btn btn-sm btn-secondary" onclick="clearSelection()">
                                <i class="bi bi-x me-1"></i>Clear
                            </button>
                        </div>
                    </div>

                    <!-- ─── Skeleton Loader ──────────────────────────────────── -->
                    <div id="skeletonWrapper">
                        <div class="table-responsive">
                        <table id="enrollTableSkeleton" class="table" aria-hidden="true">
                            <thead>
                                <tr>
                                    <th style="width:40px;"></th>
                                    <th>Student No.</th>
                                    <th>Name</th>
                                    <th>Course &amp; Section</th>
                                    <th>Subject</th>
                                    <th>Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php
                                // Show 8 skeleton rows (or match enrollment count, max 10)
                                $skeletonRows = min(max($enrollmentCount, 5), 10);
                                for ($i = 0; $i < $skeletonRows; $i++):
                                ?>
                                <tr class="skeleton-row">
                                    <td><span class="skeleton-bar skeleton-circle"></span></td>
                                    <td><span class="skeleton-bar" style="width:<?= rand(70,95) ?>px;height:13px;display:block;"></span></td>
                                    <td><span class="skeleton-bar" style="width:<?= rand(110,180) ?>px;height:13px;display:block;"></span></td>
                                    <td><span class="skeleton-bar" style="width:<?= rand(65,85) ?>px;height:13px;display:block;"></span></td>
                                    <td>
                                        <span class="skeleton-bar" style="width:<?= rand(45,60) ?>px;height:18px;display:inline-block;border-radius:4px;"></span>
                                        <span class="skeleton-bar ms-1" style="width:<?= rand(90,150) ?>px;height:13px;display:inline-block;vertical-align:middle;"></span>
                                    </td>
                                    <td><span class="skeleton-bar" style="width:32px;height:28px;display:block;border-radius:6px;"></span></td>
                                </tr>
                                <?php endfor; ?>
                            </tbody>
                        </table>
                        </div><!-- /.table-responsive -->
                    </div>
                    <!-- ─── End Skeleton Loader ─────────────────────────────── -->

                    <!-- Real Table (hidden initially) -->
                    <div class="table-wrapper" id="realTableWrapper" style="display:none;opacity:0;">
                        <div class="table-responsive">
                            <table id="enrollTable" class="table table-hover" style="width:100%">
                                <thead>
                                    <tr>
                                        <th>
                                            <div class="table-checkbox-container">
                                                <input type="checkbox" class="table-checkbox-input" id="selectAll">
                                                <label class="table-checkbox-label" for="selectAll">
                                                    <div class="table-checkbox-box"><i class="bi bi-check"></i></div>
                                                </label>
                                            </div>
                                        </th>
                                        <th>Student No.</th>
                                        <th>Name</th>
                                        <th>Course &amp; Section</th>
                                        <th>Subject</th>
                                        <th>Action</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php // Rows are built by DataTables from
                                          // get_enrollment_data_ajax.php — see
                                          // assets/js/subject_enrollment.js. ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>
    <script>
        const userRole = <?php echo json_encode($user_role); ?>;
    </script>
    <script src="<?= asset('../assets/js/subject_enrollment.js') ?>"></script>

    <script>
    (function () {
        const skeletonWrapper  = document.getElementById('skeletonWrapper');
        const realTableWrapper = document.getElementById('realTableWrapper');
        let revealed = false;

        function revealTable() {
            if (revealed) return;
            revealed = true;

            skeletonWrapper.style.transition = 'opacity .3s ease';
            skeletonWrapper.style.opacity    = '0';

            setTimeout(function () {
                skeletonWrapper.style.display = 'none';
                realTableWrapper.style.display = 'block';
                realTableWrapper.offsetHeight; // force reflow
                realTableWrapper.style.transition = 'opacity .35s ease';
                realTableWrapper.style.opacity    = '1';
            }, 300);
        }

        // Script is at bottom of <body> — DOM is already ready, no need for DOMContentLoaded.
        // Check if DataTables is already initialized (fast reload/cache case)
        if (typeof $ !== 'undefined' && $.fn && $.fn.dataTable) {
            if ($.fn.dataTable.isDataTable('#enrollTable')) {
                // Already initialized — reveal immediately
                revealTable();
            } else {
                // Not yet initialized — listen for init event
                $('#enrollTable').on('init.dt', function () {
                    revealTable();
                });
                // Safety fallback in case init.dt never fires.
                // Generous on purpose: the rows now arrive over the
                // network, and init.dt only fires once they land. A
                // short timer here would swap the skeleton for an
                // empty table on a slow connection — which reads as
                // "no enrollments", the one thing it must not say.
                setTimeout(revealTable, 15000);
            }
        } else {
            // No DataTables — fallback timer
            setTimeout(revealTable, 800);
        }
    })();
    </script>
</body>
</html>