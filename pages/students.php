<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
requirePermission('students.view');

// Viewing the list and changing it are separate grants, so each control
// on this page is rendered only for the permission that backs it. The
// matching crud/ endpoints enforce the same keys.
$canManageStudents   = can('students.manage');
$canImportStudents   = can('students.import');
$canDeleteStudents   = can('students.delete');
$canPromoteSections  = can('students.promote');
// Emptying the whole roster stays admin-only — see
// crud/delete_all_students.php.
$canDeleteAllStudents = isAdmin();
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

// Three counts for the hero. This page had no totals at all before —
// you had to wait for the table and read "Showing 1 to 10 of N" at
// the bottom.
$studentTotal = (int) (mysqli_fetch_assoc(
    mysqli_query($conn, "SELECT COUNT(*) AS n FROM students_tbl")
)['n'] ?? 0);

$courseTotal = (int) (mysqli_fetch_assoc(
    mysqli_query($conn, "SELECT COUNT(DISTINCT course) AS n FROM students_tbl")
)['n'] ?? 0);

$sectionTotal = (int) (mysqli_fetch_assoc(
    mysqli_query($conn, "SELECT COUNT(DISTINCT CONCAT(course,'-',section)) AS n FROM students_tbl")
)['n'] ?? 0);
?>
<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/students-page.css') ?>">
    <!-- Styling for the form modals (.app-modal). Must come after
         main.css to override the older rules there. -->
    <link rel="stylesheet" href="<?= asset('../assets/css/modal-form.css') ?>">
</head>

<body>
    <!-- Sidebar -->
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <!-- Content -->
    <div class="content stud-page" id="content">
        <!-- topbar -->
        <?php include("../components/topBar.php"); ?>

        <div class="stud-hero">
            <div class="stud-hero-icon"><i class="bi bi-people-fill"></i></div>
            <div class="stud-hero-text">
                <h2>Students</h2>
                <p>The master list. Every QR scan is checked against a record here.</p>
            </div>
            <div class="stud-chips">
                <span class="stud-chip">
                    <i class="bi bi-person-lines-fill"></i>
                    <?= number_format($studentTotal) ?> student<?= $studentTotal === 1 ? '' : 's' ?>
                </span>
                <span class="stud-chip">
                    <i class="bi bi-mortarboard"></i>
                    <?= number_format($courseTotal) ?> course<?= $courseTotal === 1 ? '' : 's' ?>
                </span>
                <span class="stud-chip">
                    <i class="bi bi-grid-3x3-gap"></i>
                    <?= number_format($sectionTotal) ?> section<?= $sectionTotal === 1 ? '' : 's' ?>
                </span>
            </div>
        </div>

        <div class="tab-content" id="attendanceTabsContent">
            <div class="tab-pane fade show active" id="records" role="tabpanel">
                <div>
                    <div class="stud-toolbar">
                        <div class="stud-toolbar-title">
                            <i class="bi bi-table"></i> Student Records
                        </div>
                        <!-- Five buttons in a row wrapped onto two ragged
                             lines as soon as the window narrowed, and the
                             fifth ("Delete Selected") appears without warning
                             the moment a checkbox is ticked — so the row
                             changed shape while you were using it.

                             Only the actions you reach for often stay on the
                             bar. The rare ones move into the overflow menu:
                             Import CSV, Promote Section (once a year) and
                             Delete All (which is safer one level down).

                             The ids are unchanged — importStudent.js,
                             deleteSelected.js and delStudent.js find these
                             by id, not by position. -->
                        <div class="stud-actions">
                            <?php if ($canDeleteStudents): ?>
                            <!-- Contextual: appears only once rows are ticked,
                                 so it needs to be seen, not buried. -->
                            <button class="stud-btn warn d-none" id="deleteSelectedBtn" title="Delete Selected Students">
                                <i class="bi bi-trash2-fill"></i>
                                <span class="btn-text">Delete Selected (<span id="selectedCount">0</span>)</span>
                            </button>
                            <?php endif; ?>

                            <?php if ($canImportStudents || $canPromoteSections || $canDeleteAllStudents): ?>
                            <div class="dropdown stud-more">
                                <button class="stud-btn ghost" type="button" id="studMoreBtn"
                                    data-bs-toggle="dropdown" data-bs-display="static" aria-expanded="false"
                                    title="More actions" aria-label="More actions">
                                    <i class="bi bi-three-dots"></i>
                                </button>
                                <ul class="dropdown-menu dropdown-menu-end stud-more-menu" aria-labelledby="studMoreBtn">
                                    <?php if ($canImportStudents): ?>
                                    <li>
                                        <button class="dropdown-item" type="button" id="importCsvBtn">
                                            <i class="bi bi-file-earmark-arrow-up"></i> Import CSV
                                        </button>
                                    </li>
                                    <?php endif; ?>
                                    <?php if ($canPromoteSections): ?>
                                    <li>
                                        <button class="dropdown-item" type="button" id="promoteSectionBtn"
                                            data-bs-toggle="modal" data-bs-target="#promoteSectionModal">
                                            <i class="bi bi-arrow-up-right-circle"></i> Promote Section
                                        </button>
                                    </li>
                                    <?php endif; ?>
                                    <?php if ($canDeleteAllStudents): ?>
                                    <li><hr class="dropdown-divider"></li>
                                    <li>
                                        <button class="dropdown-item is-danger" type="button" id="deleteAllBtn"
                                            onclick="confirmDeleteAll()">
                                            <i class="bi bi-trash-fill"></i> Delete All
                                        </button>
                                    </li>
                                    <?php endif; ?>
                                </ul>
                            </div>
                            <?php endif; ?>

                            <?php if ($canManageStudents): ?>
                            <!-- The one action this page is for. Kept last so
                                 it stays where it has always been. -->
                            <button class="stud-btn primary" data-bs-toggle="modal" data-bs-target="#addStudentModal">
                                <i class="bi bi-person-plus"></i>
                                <span class="btn-text">Add Student</span>
                            </button>
                            <?php endif; ?>

                            <!-- importStudent.js clicks this; it must stay in
                                 the DOM even though it is never seen. -->
                            <input type="file" id="csvFileInput" accept=".csv" style="display: none;">
                        </div>
                    </div>
                    <!-- add modal — skipped without students.manage, so it is
                         not left in the DOM with nothing able to open it -->
                    <?php if ($canManageStudents): ?>
                        <?php include __DIR__ . "/../components/add_students_modal.php"; ?>
                    <?php endif; ?>
                    <div class="stud-table-card">
                        <!-- Loading Spinner -->
                        <div id="tableLoader" class="text-center py-5">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                            <p class="mt-2 text-muted">Please wait, loading data...</p>
                        </div>

                        <?php
                        // get_students_ajax.php fetches the rows now. Every
                        // student used to be rendered here as HTML — 253 KB
                        // for 474 students, 3.5 MB for 1,762.
                        ?>

                        <!-- Table (hidden initially) -->
                        <table id="stud_tbl" class="table table-striped" style="width:100%; display:none;">
                            <thead class="table-dark">
                                <tr>
                                    <!-- ✅ Select All Checkbox -->
                                    <th style="width: 40px;">
                                        <input 
                                            type="checkbox" 
                                            id="selectAllCheckbox" 
                                            class="form-check-input" 
                                            title="Select All"
                                        >
                                    </th>
                                    <th>No.</th>
                                    <th>Student Number</th>
                                    <th>Full Name</th>
                                    <th>Course</th>
                                    <th>Section</th>
                                    <th>Added By</th>
                                    <th>Action</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <script>
            // Delete All Students Function
            function confirmDeleteAll() {
                Swal.fire({
                    title: 'Are you sure?',
                    text: "This will delete ALL students! This action cannot be undone!",
                    icon: 'warning',
                    background: '#0f172a',
                    color: '#e0e0e0',
                    showCancelButton: true,
                    confirmButtonColor: '#d33',
                    cancelButtonColor: '#3085d6',
                    confirmButtonText: 'Yes, delete all!',
                    cancelButtonText: 'Cancel'
                }).then((result) => {
                    if (result.isConfirmed) {
                        Swal.fire({
                            title: 'Deleting...',
                            text: 'Please wait',
                            allowOutsideClick: false,
                            didOpen: () => {
                                Swal.showLoading();
                            }
                        });

                        $.ajax({
                            url: '../crud/delete_all_students.php',
                            type: 'POST',
                            dataType: 'json',
                            success: function(response) {
                                if (response.success) {
                                    Swal.fire({
                                        icon: 'success',
                                        title: 'Deleted!',
                                        background: '#0f172a',
                                        color: '#e0e0e0',
                                        text: response.message,
                                        timer: 2000,
                                        showConfirmButton: false
                                    }).then(() => {
                                        location.reload();
                                    });
                                } else {
                                    Swal.fire({
                                        icon: 'error',
                                        title: 'Error!',
                                        text: response.message
                                    });
                                }
                            },
                            error: function() {
                                Swal.fire({
                                    icon: 'error',
                                    title: 'Error!',
                                    text: 'Failed to delete students. Please try again.'
                                });
                            }
                        });
                    }
                });
            }
        </script>
    </div>
    <!-- update students -->
    <?php if ($canManageStudents): ?>
        <?php include __DIR__ . "/../components/update_students_modal.php"; ?>
    <?php endif; ?>
    <!-- promote a whole section to the next year level -->
    <?php if ($canPromoteSections): ?>
        <?php include __DIR__ . "/../components/promote_section_modal.php"; ?>
    <?php endif; ?>
    <!-- script add student -->
    <script src="<?= asset('../assets/js/addStudent.js') ?>"></script>
    <!-- script student update -->
    <script src="<?= asset('../assets/js/editStudent.js') ?>"></script>
    <!-- script student delete -->
    <script src="<?= asset('../assets/js/delStudent.js') ?>"></script>
    <!-- import csv -->
    <script src="<?= asset('../assets/js/importStudent.js') ?>"></script>
    <!-- delete selected -->
    <script src="<?= asset('../assets/js/deleteSelected.js') ?>"></script>
    <!-- promote section — must load AFTER importStudent.js, whose
         top-level `esc`/`SWAL_APP`/`swalHead` it deliberately avoids
         re-declaring. -->
    <script src="<?= asset('../assets/js/promoteSection.js') ?>"></script>
    <!-- The rows are built by DataTables from get_students_ajax.php, so
         the Edit and Delete buttons are decided in JS. It reads this;
         crud/update_students.php and crud/delete_students.php enforce
         the same two permissions server-side. Must come before
         datatables.js. -->
    <script>
        window.studentPerms = {
            manage: <?= $canManageStudents ? 'true' : 'false' ?>,
            delete: <?= $canDeleteStudents ? 'true' : 'false' ?>
        };
    </script>
    <!-- script -->
    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/delete_attendance.js') ?>"></script>
    <script src="<?= asset('../assets/js/filter.js') ?>"></script>

</body>

</html>