<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if(!isAdmin()){
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
?>
<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
</head>

<body>
    <!-- Sidebar -->
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <!-- Content -->
    <div class="content" id="content">
        <!-- topbar -->
        <?php include("../components/topBar.php"); ?>

        <h2>Students List</h2>
        <div class="tab-content mt-3" id="attendanceTabsContent">
            <div class="tab-pane fade show active" id="records" role="tabpanel">
                <div class="card p-3">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <h5 class="m-0">Student Records</h5>
                        <div class="d-flex gap-2">
                            <!-- Import CSV Button -->
                            <button class="btn btn-info btn-icon" id="importCsvBtn" title="Import from CSV">
                                <i class="bi bi-file-earmark-arrow-up"></i>
                                <span class="btn-text">Import Student CSV</span>
                            </button>
                            <input type="file" id="csvFileInput" accept=".csv" style="display: none;">

                            <!-- Delete Selected Button (hidden by default) -->
                            <button class="btn btn-warning btn-icon d-none" id="deleteSelectedBtn" title="Delete Selected Students">
                                <i class="bi bi-trash2-fill"></i>
                                <span class="btn-text">Delete Selected (<span id="selectedCount">0</span>)</span>
                            </button>

                            <!-- Delete All Button -->
                            <button class="btn btn-danger btn-icon" id="deleteAllBtn" onclick="confirmDeleteAll()" title="Delete All Students">
                                <i class="bi bi-trash-fill"></i>
                                <span class="btn-text">Delete All Student</span>
                            </button>

                            <!-- Add Student Button -->
                            <button class="btn btn-primary btn-icon" data-bs-toggle="modal" data-bs-target="#addStudentModal">
                                <i class="bi bi-person-plus"></i>
                                <span class="btn-text">Add Student</span>
                            </button>
                        </div>
                    </div>
                    <!-- add modal -->
                    <?php include __DIR__ . "/../components/add_students_modal.php"; ?>
                    <div class="card">
                        <!-- Loading Spinner -->
                        <div id="tableLoader" class="text-center py-5">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                            <p class="mt-2 text-muted">Please wait, loading data...</p>
                        </div>

                        <?php
                        include __DIR__ . "/../includes/db_connect.php";
                        $user_id = $_SESSION['user_id'];

                        $sql = "SELECT s.id, s.student_no, s.fullname, s.course, s.section, 
                                u.name as added_by_name
                                FROM students_tbl s
                                LEFT JOIN users u ON s.user_id = u.id";

                        $result = $conn->query($sql);
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
                            <tbody>
                                <?php if ($result->num_rows > 0): ?>
                                    <?php $counter = 1; ?>
                                    <?php while ($row = $result->fetch_assoc()): ?>
                                        <tr id="row-<?= $row['id']; ?>">
                                            <!-- ✅ Per-row Checkbox -->
                                            <td>
                                                <input 
                                                    type="checkbox" 
                                                    class="form-check-input row-checkbox" 
                                                    value="<?= $row['id']; ?>"
                                                >
                                            </td>
                                            <td><?= $counter++; ?></td>
                                            <td><?= htmlspecialchars($row['student_no']); ?></td>
                                            <td><?= htmlspecialchars($row['fullname']); ?></td>
                                            <td><?= htmlspecialchars($row['course']); ?></td>
                                            <td><?= htmlspecialchars($row['section']); ?></td>
                                            <td><?= htmlspecialchars($row['added_by_name'] ?? 'N/A'); ?></td>
                                            <td>
                                                <button
                                                    class="btn btn-sm btn-success me-2"
                                                    onclick="editStudent(
                              '<?= $row['id']; ?>',
                              '<?= htmlspecialchars($row['student_no']); ?>',
                              '<?= htmlspecialchars($row['fullname']); ?>',
                              '<?= htmlspecialchars($row['course']); ?>',
                              '<?= htmlspecialchars($row['section']); ?>'
                            )">
                                                    <i class="bi bi-pencil-square"></i>
                                                </button>
                                                <button class="btn btn-sm btn-danger btn-deletes" data-id="<?= $row['id']; ?>">
                                                    <i class="bi bi-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    <?php endwhile; ?>
                                <?php else: ?>

                                <?php endif; ?>
                            </tbody>
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
    <script src="../assets/js/addStudent.js"></script>
    <!-- script student update -->
    <script src="../assets/js/editStudent.js"></script>
    <!-- script student delete -->
    <script src="../assets/js/delStudent.js"></script>
    <!-- import csv -->
    <script src="../assets/js/importStudent.js"></script>
    <!-- delete selected -->
    <script src="../assets/js/deleteSelected.js"></script>
    <!-- script -->
    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="../assets/js/comingSoon.js"></script>
    <script src="../assets/js/logout.js"></script>
    <script src="../assets/js/toggleSidebar.js"></script>
    <script src="../assets/js/datatables.js"></script>
    <script src="../assets/js/delete_attendance.js"></script>
    <script src="../assets/js/filter.js"></script>

</body>

</html>