<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);

$user_role = $_SESSION['role'];
?>
<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <title>Generate Attendance Links</title>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="../assets/css/daily_attendance.css">
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

<body style="display: block !important;">
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="container-fluid px-4 py-3">

            <!-- Page header -->
            <div class="d-flex align-items-center justify-content-between mb-4 flex-wrap gap-2">
                <div>
                    <h3 class="mb-0 fw-semibold">Attendance Links</h3>
                    <small class="text-muted">Generate and share short links for student attendance</small>
                </div>
                <div class="d-flex align-items-center gap-2">
                    <span class="count-badge">
                        <i class="bi bi-collection me-1"></i>
                        <span id="visibleCount">—</span> of <span id="totalCount">—</span> subject(s)
                    </span>
                </div>
            </div>

            <!-- Search + filter row -->
            <div class="row g-3 mb-4">
                <div class="col-md-6">
                    <div class="search-wrap">
                        <i class="bi bi-search"></i>
                        <input type="text" id="searchInput" class="form-control"
                            placeholder="Search by subject, section, or instructor…" autocomplete="off">
                    </div>
                </div>
                <div class="col-md-3">
                    <select id="filterSection" class="form-select" style="border-radius:10px;">
                        <option value="">All Sections</option>
                    </select>
                </div>
                <div class="col-md-3">
                    <select id="filterOwner" class="form-select" style="border-radius:10px;">
                        <option value="">All Subjects</option>
                        <?php if ($user_role === 'admin'): ?>
                            <option value="mine">My Subjects Only</option>
                            <option value="others">Others' Subjects</option>
                        <?php endif; ?>
                    </select>
                </div>
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
                    <div class="d-inline-flex align-items-center justify-content-center rounded-circle mb-4"
                        style="width:90px; height:90px; background:rgba(13,110,253,.08); border:1px solid rgba(13,110,253,.15);">
                        <i class="bi bi-journal-x" style="font-size:2.5rem; color:#6ea8fe;"></i>
                    </div>
                    <h5 class="fw-semibold mb-2">No Subjects Available</h5>
                    <p class="text-muted mb-4" style="font-size:.9rem; max-width:380px; margin:0 auto;">
                        No attendance links can be generated yet. Please make sure subjects and enrollments are properly set up.
                    </p>
                    <div class="d-flex justify-content-center gap-3 flex-wrap">
                        <div class="px-4 py-3 rounded-3 text-start" style="background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08); min-width:200px;">
                            <div class="d-flex align-items-center gap-2 mb-1">
                                <i class="bi bi-1-circle-fill text-primary"></i>
                                <span class="fw-semibold" style="font-size:.85rem;">Assign Subjects</span>
                            </div>
                            <p class="text-muted mb-0" style="font-size:.8rem;">Link instructors to subjects in the subject management page.</p>
                        </div>
                        <div class="px-4 py-3 rounded-3 text-start" style="background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08); min-width:200px;">
                            <div class="d-flex align-items-center gap-2 mb-1">
                                <i class="bi bi-2-circle-fill text-success"></i>
                                <span class="fw-semibold" style="font-size:.85rem;">Enroll Students</span>
                            </div>
                            <p class="text-muted mb-0" style="font-size:.8rem;">Make sure students are enrolled in their respective subjects.</p>
                        </div>
                    </div>
                </div>
            </div>

            <div id="noResults" style="display:none;">
                <div class="text-center py-5 mt-3">
                    <div class="d-inline-flex align-items-center justify-content-center rounded-circle mb-4"
                        style="width:80px; height:80px; background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08);">
                        <i class="bi bi-search" style="font-size:2rem; color:#6c757d;"></i>
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
            <div class="modal-content" style="border-radius:16px; border:1px solid rgba(13,110,253,.3); background:#0d1117;">
                <div class="modal-header border-0 pb-0">
                    <div>
                        <h5 class="modal-title fw-bold mb-0"><i class="bi bi-qr-code me-2 text-primary"></i>Attendance QR Code</h5>
                        <small class="text-muted" id="qrSubjectName"></small>
                    </div>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body text-center py-4">
                    <div class="mb-3 d-flex justify-content-center gap-2 flex-wrap">
                        <span class="badge fs-6 px-3 py-2" style="background:rgba(13,110,253,.15); color:#6ea8fe; border:1px solid rgba(13,110,253,.3); border-radius:8px;">
                            <i class="bi bi-book me-1"></i><span id="qrSubjectCode"></span>
                        </span>
                        <span class="badge fs-6 px-3 py-2" style="background:rgba(13,110,253,.08); color:#adb5bd; border:1px solid rgba(255,255,255,.1); border-radius:8px;">
                            <span id="qrSubjectFullName"></span>
                        </span>
                    </div>
                    <div class="d-inline-block p-3 rounded-4" style="background:#0a1628; box-shadow:0 0 30px rgba(0,200,255,.4);">
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
    <script src="../assets/js/profileUpdate.js"></script>
    <script src="../assets/js/comingSoon.js"></script>
    <script src="../assets/js/logout.js"></script>
    <script src="../assets/js/toggleSidebar.js"></script>
    <script src="../assets/js/datatables.js"></script>
    <script src="../assets/js/lock.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
    <script src="../assets/js/generate_link.js"></script>
</body>
</html>