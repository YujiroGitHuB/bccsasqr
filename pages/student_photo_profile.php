<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";        // require login (admin OR instructor)
include "../includes/db_connect.php";

$user_id     = (int) $_SESSION['user_id'];
$isAdminUser = isAdmin();

// ── Scope: admins see all students; instructors see only their sections ──────
// Build a reusable "AND (s.course, s.section) IN (...)" fragment for instructors.
$scopeSql    = '';
$scopeTypes  = '';
$scopeParams = [];
if (!$isAdminUser) {
    $secStmt = $conn->prepare("SELECT course, section FROM instructor_section_tbl WHERE instructor_id = ?");
    $secStmt->bind_param("i", $user_id);
    $secStmt->execute();
    $secRes = $secStmt->get_result();
    $pairs  = [];
    while ($p = $secRes->fetch_assoc()) $pairs[] = $p;
    $secStmt->close();

    if (empty($pairs)) {
        $scopeSql = ' AND 1=0 '; // no assigned sections → no students
    } else {
        $tuples   = implode(',', array_fill(0, count($pairs), '(?,?)'));
        $scopeSql = " AND (s.course, s.section) IN ($tuples) ";
        foreach ($pairs as $p) {
            $scopeParams[] = $p['course'];
            $scopeParams[] = $p['section'];
            $scopeTypes   .= 'ss';
        }
    }
}

// Helper: run a scoped COUNT query.
function scopedCount(mysqli $conn, string $sql, string $types, array $params): int {
    $stmt = $conn->prepare($sql);
    if ($types !== '') $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $n = (int) $stmt->get_result()->fetch_row()[0];
    $stmt->close();
    return $n;
}

$total_students = scopedCount(
    $conn,
    "SELECT COUNT(*) FROM students_tbl s WHERE 1=1 $scopeSql",
    $scopeTypes, $scopeParams
);
$with_photo = scopedCount(
    $conn,
    "SELECT COUNT(*) FROM students_tbl s
     INNER JOIN student_photos p ON p.s_id = s.id
     WHERE p.photo_path IS NOT NULL $scopeSql",
    $scopeTypes, $scopeParams
);
$without_photo = $total_students - $with_photo;
$pct           = $total_students > 0 ? round($with_photo / $total_students * 100) : 0;

// NOTE: The student rows are loaded on demand (paginated + searchable) via
// api/get_student_photos.php — see studPhotoProfile.js. We intentionally do
// NOT fetch every student here; that did not scale.
$courseStmt = $conn->prepare("SELECT DISTINCT s.course FROM students_tbl s WHERE 1=1 $scopeSql ORDER BY s.course");
if ($scopeTypes !== '') $courseStmt->bind_param($scopeTypes, ...$scopeParams);
$courseStmt->execute();
$courses = $courseStmt->get_result()->fetch_all(MYSQLI_ASSOC);
$courseStmt->close();

$sectionStmt = $conn->prepare("SELECT DISTINCT s.section FROM students_tbl s WHERE 1=1 $scopeSql ORDER BY s.section");
if ($scopeTypes !== '') $sectionStmt->bind_param($scopeTypes, ...$scopeParams);
$sectionStmt->execute();
$sections = $sectionStmt->get_result()->fetch_all(MYSQLI_ASSOC);
$sectionStmt->close();
?>
<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <?php
    // Dropped the three webfonts (Syne / JetBrains Mono / Outfit) and
    // the second copy of Bootstrap Icons: every other page uses the
    // native font stack, and the icons are already linked in
    // includes/header.php.
    ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/studPhotoPofile.css') ?>">
    <!-- Styling for spDelModal (.app-modal) -->
    <link rel="stylesheet" href="<?= asset('../assets/css/modal-form.css') ?>">
</head>
<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content sp" id="content">
        <?php include("../components/topBar.php"); ?>

        <!-- Hero — the same shape as .stud-hero and .dash-hero -->
        <div class="sp-hero">
            <div class="sp-hero-icon"><i class="bi bi-person-badge-fill"></i></div>
            <div class="sp-hero-text">
                <h2>Student Photo Profiles</h2>
                <p>The face shown to the scanner when a QR is checked in.</p>
            </div>
            <div class="sp-chips">
                <span class="sp-chip">
                    <i class="bi bi-people-fill"></i>
                    <?= number_format($total_students) ?> student<?= $total_students === 1 ? '' : 's' ?>
                </span>
                <span class="sp-chip">
                    <i class="bi bi-mortarboard"></i>
                    <?= count($courses) ?> course<?= count($courses) === 1 ? '' : 's' ?>
                </span>
            </div>
        </div>

        <!-- Stats -->
        <div class="sp-stats">
            <div class="sp-stat total">
                <div class="sp-stat-icon"><i class="bi bi-people-fill"></i></div>
                <div class="sp-stat-val"><?= number_format($total_students) ?></div>
                <div class="sp-stat-lbl">Total students</div>
            </div>
            <div class="sp-stat has">
                <div class="sp-stat-icon"><i class="bi bi-person-check-fill"></i></div>
                <div class="sp-stat-val"><?= number_format($with_photo) ?></div>
                <div class="sp-stat-lbl">With photo</div>
            </div>
            <div class="sp-stat missing">
                <div class="sp-stat-icon"><i class="bi bi-person-x-fill"></i></div>
                <div class="sp-stat-val"><?= number_format($without_photo) ?></div>
                <div class="sp-stat-lbl">No photo yet</div>
            </div>
            <div class="sp-stat prog">
                <div class="sp-prog-head">
                    <div class="sp-prog-lbl">Photo coverage</div>
                    <div class="sp-prog-pct"><?= $pct ?><small>%</small></div>
                </div>
                <!-- The width comes from here; `.sp-fill` had no base
                     rule before, so the bar was always empty. -->
                <div class="sp-track">
                    <div class="sp-fill" style="width: <?= $pct ?>%"></div>
                </div>
                <div class="sp-prog-sub">
                    <?= number_format($with_photo) ?> of <?= number_format($total_students) ?> students have uploaded a photo
                </div>
            </div>
        </div>

        <!-- Toolbar -->
        <div class="sp-toolbar">
            <div class="sp-srch">
                <input type="text" id="spQ" placeholder="Search name or student no…" autocomplete="off"
                    aria-label="Search students by name or student number">
                <i class="bi bi-search sp-srch-ico" aria-hidden="true"></i>
            </div>
            <select class="sp-sel" id="spCourse" aria-label="Filter by course">
                <option value="">All Courses</option>
                <?php foreach ($courses as $c): ?>
                    <option value="<?= htmlspecialchars($c['course']) ?>"><?= htmlspecialchars($c['course']) ?></option>
                <?php endforeach; ?>
            </select>
            <select class="sp-sel" id="spSection" aria-label="Filter by section">
                <option value="">All Sections</option>
                <?php foreach ($sections as $sec): ?>
                    <option value="<?= htmlspecialchars($sec['section']) ?>"><?= htmlspecialchars($sec['section']) ?></option>
                <?php endforeach; ?>
            </select>
            <div class="sp-pills" role="group" aria-label="Filter by photo status">
                <button type="button" class="sp-pill on" data-f="all"><i class="bi bi-grid-3x3-gap-fill" aria-hidden="true"></i> All</button>
                <button type="button" class="sp-pill g" data-f="with"><i class="bi bi-check-circle-fill" aria-hidden="true"></i> With photo</button>
                <button type="button" class="sp-pill a" data-f="without"><i class="bi bi-exclamation-circle-fill" aria-hidden="true"></i> Missing</button>
            </div>
        </div>

        <div class="sp-meta">
            Showing <strong id="spCnt">0</strong> students<span id="spTag"></span>
        </div>

        <!-- Skeleton (shown while the first page loads) -->
        <div class="sp-grid" id="skGrid">
            <?php for ($i = 0; $i < 12; $i++): ?>
                <div class="sk-card">
                    <div class="sk sk-circle sk-av"></div>
                    <div class="sk sk-n"></div>
                    <div class="sk sk-sn"></div>
                    <div class="sk sk-co"></div>
                    <div class="sk sk-bdg"></div>
                </div>
            <?php endfor; ?>
        </div>

        <!-- Real Grid — populated on demand by studPhotoProfile.js -->
        <div class="sp-grid" id="spGrid"></div>

        <!-- Load more -->
        <div class="sp-more-wrap">
            <button id="spMore" class="sp-more" style="display:none;">
                <i class="bi bi-arrow-down-circle"></i> Load more
            </button>
        </div>
    </div>

    <!-- Delete Modal
         Styling: assets/css/modal-form.css (.app-modal). Every element
         used to carry its own inline style — including a 'Syne'
         heading and two equally sized buttons, which gave Cancel and
         Remove the same weight. -->
    <div class="modal fade app-modal" id="spDelModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <div class="app-modal-icon is-crit"><i class="bi bi-trash3-fill"></i></div>
                    <div class="app-modal-heading">
                        <h5 class="modal-title">Remove this photo?</h5>
                        <p>The student can upload a new one anytime.</p>
                    </div>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <p class="sp-del-msg">
                        This clears the photo on file for <strong id="spDelName"></strong>.
                        Attendance records are not affected.
                    </p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="app-btn ghost" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="app-btn danger" id="spDelOk">
                        <i class="bi bi-trash3" aria-hidden="true"></i> Remove photo
                    </button>
                </div>
            </div>
        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script>window.SP_IS_ADMIN = <?= $isAdminUser ? 'true' : 'false' ?>;</script>
    <script src="<?= asset('../assets/js/studPhotoProfile.js') ?>"></script>
</body>

</html>