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
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=JetBrains+Mono:wght@400;500;600&family=Outfit:wght@300;400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="<?= asset('../assets/css/studPhotoPofile.css') ?>">
</head>
<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content sp" id="content">
        <?php include("../components/topBar.php"); ?>

        <!-- Page Header -->
        <div class="sp-header">
            <div class="sp-header-left">
                <h2 class="sp-title">Student <span>Photo</span> Profiles</h2>
                <p class="sp-sub">Monitor and manage QR attendance photo uploads</p>
            </div>
        </div>

        <!-- Stats -->
        <div class="sp-stats">
            <div class="sp-stat total">
                <div class="sp-stat-icon"><i class="bi bi-people-fill"></i></div>
                <div class="sp-stat-val"><?= number_format($total_students) ?></div>
                <div class="sp-stat-lbl">Total Students</div>
            </div>
            <div class="sp-stat has">
                <div class="sp-stat-icon"><i class="bi bi-person-check-fill"></i></div>
                <div class="sp-stat-val"><?= number_format($with_photo) ?></div>
                <div class="sp-stat-lbl">With Photo</div>
            </div>
            <div class="sp-stat missing">
                <div class="sp-stat-icon"><i class="bi bi-person-x-fill"></i></div>
                <div class="sp-stat-val"><?= number_format($without_photo) ?></div>
                <div class="sp-stat-lbl">No Photo</div>
            </div>
            <div class="sp-stat prog">
                <div class="sp-prog-head">
                    <div>
                        <div class="sp-stat-icon" style="margin-bottom:.4rem;"><i class="bi bi-bar-chart-fill"></i></div>
                        <div class="sp-prog-lbl">Photo Coverage</div>
                    </div>
                    <div class="sp-prog-pct"><?= $pct ?><small>%</small></div>
                </div>
                <div class="sp-track">
                    <div class="sp-fill"></div>
                </div>
                <div class="sp-prog-sub">
                    <span><?= number_format($with_photo) ?> uploaded</span>
                    <span><?= number_format($without_photo) ?> remaining</span>
                </div>
            </div>
        </div>

        <!-- Toolbar -->
        <div class="sp-toolbar">
            <div class="sp-srch">
                <input type="text" id="spQ" placeholder="Search name or student no…" autocomplete="off">
                <i class="bi bi-search sp-srch-ico"></i>
            </div>
            <select class="sp-sel" id="spCourse">
                <option value="">All Courses</option>
                <?php foreach ($courses as $c): ?>
                    <option value="<?= htmlspecialchars($c['course']) ?>"><?= htmlspecialchars($c['course']) ?></option>
                <?php endforeach; ?>
            </select>
            <select class="sp-sel" id="spSection">
                <option value="">All Sections</option>
                <?php foreach ($sections as $sec): ?>
                    <option value="<?= htmlspecialchars($sec['section']) ?>"><?= htmlspecialchars($sec['section']) ?></option>
                <?php endforeach; ?>
            </select>
            <div class="sp-pills">
                <button class="sp-pill on" data-f="all"><i class="bi bi-grid-3x3-gap-fill"></i> All</button>
                <button class="sp-pill g" data-f="with"><i class="bi bi-check-circle-fill"></i> With</button>
                <button class="sp-pill a" data-f="without"><i class="bi bi-exclamation-circle-fill"></i> None</button>
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
        <div class="sp-more-wrap" style="text-align:center; margin-top:1.5rem;">
            <button id="spMore" class="btn" style="display:none;">
                <i class="bi bi-arrow-down-circle"></i> Load more
            </button>
        </div>
    </div>

    <!-- Delete Modal -->
    <div class="modal fade" id="spDelModal" tabindex="-1">
        <div class="modal-dialog modal-sm modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-body text-center p-4">
                    <div class="sp-del-icon">
                        <i class="bi bi-trash3-fill"></i>
                    </div>
                    <h6 style="font-family:'Syne',sans-serif;font-weight:800;margin-bottom:.35rem;font-size:.95rem;letter-spacing:-.02em;">
                        Remove Photo?
                    </h6>
                    <p id="spDelMsg" style="font-size:.8rem;color:#718096;margin-bottom:1.3rem;line-height:1.6;"></p>
                    <div class="d-flex gap-2">
                        <button class="btn btn-sm flex-fill" data-bs-dismiss="modal"
                            style="background:#131c2b;border:1px solid rgba(255,255,255,.08);color:#a0aec0;font-size:.82rem;">
                            Cancel
                        </button>
                        <button class="btn btn-sm btn-danger flex-fill" id="spDelOk"
                            style="font-size:.82rem;font-weight:600;">
                            <i class="bi bi-trash3"></i> Remove
                        </button>
                    </div>
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