<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if(!isAdmin()){
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

// Tatlong bilang para sa hero. Walang anumang kabuuan ang page na
// ito noon — kailangan mo pang hintayin ang table at basahin ang
// "Showing 1 to 10 of N" sa ibaba.
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
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/students-page.css') ?>">
    <!-- Anyo ng mga modal na may porma (.app-modal). Dapat kasunod ng
         main.css para mabawi ang mga lumang panuntunan doon. -->
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
                        <div class="stud-actions">
                            <!-- Import CSV Button -->
                            <button class="stud-btn ghost" id="importCsvBtn" title="Import from CSV">
                                <i class="bi bi-file-earmark-arrow-up"></i>
                                <span class="btn-text">Import CSV</span>
                            </button>
                            <input type="file" id="csvFileInput" accept=".csv" style="display: none;">

                            <!-- Delete Selected Button (hidden by default) -->
                            <button class="stud-btn warn d-none" id="deleteSelectedBtn" title="Delete Selected Students">
                                <i class="bi bi-trash2-fill"></i>
                                <span class="btn-text">Delete Selected (<span id="selectedCount">0</span>)</span>
                            </button>

                            <!-- Delete All Button -->
                            <button class="stud-btn danger" id="deleteAllBtn" onclick="confirmDeleteAll()" title="Delete All Students">
                                <i class="bi bi-trash-fill"></i>
                                <span class="btn-text">Delete All</span>
                            </button>

                            <!-- Add Student Button — ang tanging punong aksyon -->
                            <button class="stud-btn primary" data-bs-toggle="modal" data-bs-target="#addStudentModal">
                                <i class="bi bi-person-plus"></i>
                                <span class="btn-text">Add Student</span>
                            </button>
                        </div>
                    </div>
                    <!-- add modal -->
                    <?php include __DIR__ . "/../components/add_students_modal.php"; ?>
                    <div class="stud-table-card">
                        <!-- Loading Spinner -->
                        <div id="tableLoader" class="text-center py-5">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                            <p class="mt-2 text-muted">Please wait, loading data...</p>
                        </div>

                        <?php
                        // Kinukuha na ng get_students_ajax.php ang mga row.
                        // Dating ini-render dito ang lahat ng estudyante bilang
                        // HTML — 253 KB sa 474 na estudyante, 3.5 MB sa 1,762.
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
    <?php include __DIR__ . "/../components/update_students_modal.php"; ?>
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