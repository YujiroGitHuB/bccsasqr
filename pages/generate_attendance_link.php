<?php require_once __DIR__ . '/../includes/asset.php';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
requirePermission('links.manage');

$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);

$user_role = $_SESSION['role'];
?>
<!doctype html>
<html lang="en">

<head>
    <title>Generate Attendance Links</title>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/daily_attendance.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/links-page.css') ?>">
    <style>
        /* Skeleton loader */
        .skeleton-card {
            background: rgba(255,255,255,.04);
            border: 1px solid rgba(255,255,255,.08);
            border-radius: 14px;
            padding: 1.25rem;
            height: 210px;
        }
        .skeleton-line {
            background: linear-gradient(90deg, rgba(255,255,255,.06) 25%, rgba(255,255,255,.12) 50%, rgba(255,255,255,.06) 75%);
            background-size: 200% 100%;
            animation: shimmer 1.4s infinite;
            border-radius: 6px;
            height: 14px;
            margin-bottom: 10px;
        }
        .skeleton-line.short  { width: 40%; }
        .skeleton-line.medium { width: 65%; }
        .skeleton-line.long   { width: 90%; }
        .skeleton-line.full   { width: 100%; }
        .skeleton-line.pill   { width: 80px; height: 28px; border-radius: 20px; }
        @keyframes shimmer {
            0%   { background-position: 200% 0; }
            100% { background-position: -200% 0; }
        }
    </style>
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content link-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <!-- px-3 on phones, px-4 on larger screens: 24px per side is
             too much when the screen is only 375px -->
        <div class="container-fluid px-3 px-md-4 py-3">

            <div class="lnk-hero">
                <div class="lnk-hero-icon"><i class="bi bi-link-45deg"></i></div>
                <div class="lnk-hero-text">
                    <h2>Attendance Links</h2>
                    <p>Short links and QR codes students open to record their own attendance.</p>
                </div>
                <span class="count-badge">
                    <i class="bi bi-collection"></i>
                    <span id="visibleCount">—</span> of <span id="totalCount">—</span> subject(s)
                </span>
            </div>

            <!-- Search + filter row -->
            <div class="lnk-filters">
                <div class="search-wrap">
                    <i class="bi bi-search"></i>
                    <input type="text" id="searchInput" class="form-control"
                        placeholder="Search by subject, section, or instructor…" autocomplete="off">
                </div>
                <select id="filterSection" class="form-select" style="min-width:170px">
                    <option value="">All Sections</option>
                </select>
                <select id="filterOwner" class="form-select" style="min-width:180px">
                    <option value="">All Subjects</option>
                    <?php if ($user_role === 'admin'): ?>
                        <option value="mine">My Subjects Only</option>
                        <option value="others">Others' Subjects</option>
                    <?php endif; ?>
                </select>
            </div>

            <!-- Skeleton loader (shown while AJAX loads) -->
            <div id="skeletonLoader" class="row g-3">
                <?php for ($i = 0; $i < 6; $i++): ?>
                    <div class="col-xl-4 col-md-6">
                        <div class="skeleton-card">
                            <div class="d-flex justify-content-between mb-3">
                                <div class="skeleton-line pill"></div>
                                <div class="skeleton-line pill"></div>
                            </div>
                            <div class="skeleton-line medium"></div>
                            <div class="skeleton-line short mt-1"></div>
                            <div class="skeleton-line full mt-3"></div>
                            <div class="skeleton-line long mt-2"></div>
                            <div class="d-flex gap-2 mt-3">
                                <div class="skeleton-line pill"></div>
                                <div class="skeleton-line pill"></div>
                                <div class="skeleton-line pill"></div>
                            </div>
                        </div>
                    </div>
                <?php endfor; ?>
            </div>

            <!-- Cards container (hidden until AJAX loads) -->
            <div class="row g-3" id="cardsContainer" style="display:none !important;"></div>

            <!-- Empty state (hidden by default) -->
            <div id="emptyState" style="display:none;">
                <div class="text-center py-5 mt-3">
                    <div class="lnk-empty-icon mb-4"><i class="bi bi-journal-x"></i></div>
                    <h5 class="fw-semibold mb-2">No Subjects Available</h5>
                    <p class="text-muted mb-4" style="font-size:.9rem; max-width:380px; margin:0 auto;">
                        No attendance links can be generated yet. Please make sure subjects and enrollments are properly set up.
                    </p>
                    <div class="d-flex justify-content-center gap-3 flex-wrap">
                        <div class="lnk-step">
                            <div class="d-flex align-items-center gap-2 mb-1">
                                <i class="bi bi-1-circle-fill num"></i>
                                <span class="fw-semibold" style="font-size:.85rem;">Assign Subjects</span>
                            </div>
                            <p class="text-muted mb-0" style="font-size:.8rem;">Link instructors to subjects in the subject management page.</p>
                        </div>
                        <div class="lnk-step">
                            <div class="d-flex align-items-center gap-2 mb-1">
                                <i class="bi bi-2-circle-fill num"></i>
                                <span class="fw-semibold" style="font-size:.85rem;">Enroll Students</span>
                            </div>
                            <p class="text-muted mb-0" style="font-size:.8rem;">Make sure students are enrolled in their respective subjects.</p>
                        </div>
                    </div>
                </div>
            </div>

            <div id="noResults" style="display:none;">
                <div class="text-center py-5 mt-3">
                    <div class="lnk-empty-icon mb-4" style="color:#6c757d; background:rgba(255,255,255,.04); border-color:rgba(255,255,255,.08);">
                        <i class="bi bi-search"></i>
                    </div>
                    <h5 class="fw-semibold mb-2">No matches found</h5>
                    <p class="text-muted mb-0" style="font-size:.9rem;">Try a different keyword or clear your filters.</p>
                </div>
            </div>

        </div>
    </div>

    <!-- QR Modal -->
    <div class="modal fade" id="qrModal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content lnk-qr-modal">
                <div class="modal-header border-0 pb-0">
                    <div>
                        <h5 class="modal-title fw-bold mb-0"><i class="bi bi-qr-code me-2"></i>Attendance QR Code</h5>
                        <small class="text-muted" id="qrSubjectName"></small>
                    </div>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body text-center py-4">
                    <div class="mb-3 d-flex justify-content-center gap-2 flex-wrap">
                        <span class="lnk-qr-chip">
                            <i class="bi bi-book"></i><span id="qrSubjectCode"></span>
                        </span>
                        <span class="lnk-qr-chip plain">
                            <span id="qrSubjectFullName"></span>
                        </span>
                    </div>
                    <!-- White plate: a QR needs contrast for a camera to
                         read it. The old dark #0a1628 plate relied on
                         the color of the QR modules themselves for
                         contrast. -->
                    <div class="lnk-qr-plate">
                        <div id="qrcode"></div>
                    </div>
                    <p class="mt-3 text-muted small"><i class="bi bi-phone me-1"></i>Students can scan this to open the attendance form</p>
                </div>
                <div class="modal-footer border-0 pt-0">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                    <button type="button" class="btn btn-primary" onclick="downloadQR()">
                        <i class="bi bi-download me-1"></i>Download
                    </button>
                </div>
            </div>
        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/profileUpdate.js') ?>"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
    <script src="<?= asset('../assets/js/generate_link.js') ?>"></script>
</body>
</html>