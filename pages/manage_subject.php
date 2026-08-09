<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if (!isAdmin()) {
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

// Get current system configuration
$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);
$systemName = $system['system_name'] ?? '';
$systemAcronym = $system['system_acronym'] ?? '';
$systemLogo = $system['logo'] ?? '';
?>

<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="../assets/css/settings.css">
    <link rel="stylesheet" href="../assets/css/management-pages.css">
    <!-- SweetAlert2 CSS -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="page-header">
            <h2> Manage Subjects</h2>
        </div>

        <div class="row">
            <!-- LEFT PANEL: ADD SUBJECT -->
            <div class="col-lg-4 col-md-12 mb-4">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-plus-circle-fill"></i>
                        <h4 id="formTitle">Add New Subject</h4>
                    </div>

                    <form id="addSubjectForm" method="post">
                        <input type="hidden" id="subjectId" name="subject_id">

                        <div class="mb-3">
                            <label class="form-label">
                                <i class="bi bi-hash"></i> Subject Code
                            </label>
                            <input
                                type="text"
                                id="subjectCode"
                                name="subject_code"
                                class="form-control"
                                placeholder="e.g., CS101"
                                required>
                        </div>

                        <div class="mb-3">
                            <label class="form-label">
                                <i class="bi bi-book"></i> Subject Name
                            </label>
                            <input
                                type="text"
                                id="subjectName"
                                name="subject_name"
                                class="form-control"
                                placeholder="e.g., Introduction to Programming"
                                required>
                        </div>

                        <button type="submit" class="btn btn-primary w-100" id="submitBtn">
                            <i class="bi bi-save"></i> Save Subject
                        </button>

                        <button type="button" class="btn btn-secondary w-100 mt-2" id="cancelBtn" style="display: none;">
                            <i class="bi bi-x-circle"></i> Cancel
                        </button>
                    </form>
                </div>
            </div>

            <!-- RIGHT PANEL: SUBJECT TABLE -->
            <div class="col-lg-8 col-md-12">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-table"></i>
                        <h4>Subject List</h4>
                        <span class="badge-count ms-auto" id="subjectCount">
                            <?php
                            $countQuery = mysqli_query($conn, "SELECT COUNT(*) as total FROM subjects_tbl");
                            $count = mysqli_fetch_assoc($countQuery)['total'];
                            echo $count . ' ' . ($count == 1 ? 'Subject' : 'Subjects');
                            ?>
                        </span>
                    </div>

                    <div class="table-wrapper">
                        <div class="table-responsive">
                            <table class="table table-dark table-hover" id="subjectTable">
                                <thead>
                                    <tr>
                                        <th style="width: 60px;">#</th>
                                        <th>Code</th>
                                        <th>Name</th>
                                        <th style="width: 180px;">Action</th>
                                    </tr>
                                </thead>
                                <tbody id="subjectTableBody">
                                    <?php
                                    $subjects = mysqli_query($conn, "SELECT * FROM subjects_tbl ORDER BY subject_code ASC");

                                    if (mysqli_num_rows($subjects) > 0) {
                                        $i = 1;
                                        while ($row = mysqli_fetch_assoc($subjects)) {
                                    ?>
                                            <tr>
                                                <td><?= $i++ ?></td>
                                                <td><strong><?= htmlspecialchars($row['subject_code']) ?></strong></td>
                                                <td><?= htmlspecialchars($row['subject_name']) ?></td>
                                                <td>
                                                    <button
                                                        class="btn btn-sm btn-success edit-btn"
                                                        data-id="<?= $row['id'] ?>"
                                                        data-code="<?= htmlspecialchars($row['subject_code']) ?>"
                                                        data-name="<?= htmlspecialchars($row['subject_name']) ?>">
                                                        <i class="bi bi-pencil"></i>
                                                    </button>
                                                    <button
                                                        class="btn btn-sm btn-danger delete-btn"
                                                        data-id="<?= $row['id'] ?>"
                                                        data-code="<?= htmlspecialchars($row['subject_code']) ?>">
                                                        <i class="bi bi-trash"></i>
                                                    </button>
                                                </td>
                                            </tr>
                                    <?php
                                        }
                                    }
                                    ?>

                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <!-- SweetAlert2 JS -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

    <script src="../assets/js/comingSoon.js"></script>
    <script src="../assets/js/logout.js"></script>
    <script src="../assets/js/toggleSidebar.js"></script>
    <script src="../assets/js/datatables.js"></script>
    <script src="../assets/js/lock.js"></script>
    <script src="../assets/js/systemConfig.js"></script>

    <script>
        let isEditMode = false;

        // Configure SweetAlert2 dark theme
        const Toast = Swal.mixin({
            toast: true,
            position: 'top-end',
            showConfirmButton: false,
            timer: 2000,
            timerProgressBar: true,
            background: '#1a1a2e',
            color: '#fff',
            didOpen: (toast) => {
                toast.addEventListener('mouseenter', Swal.stopTimer)
                toast.addEventListener('mouseleave', Swal.resumeTimer)
            }
        });

        // Add subject form submission
        document.getElementById('addSubjectForm').addEventListener('submit', function(e) {
            e.preventDefault();

            let formData = new FormData(this);
            let submitBtn = document.getElementById('submitBtn');
            let originalBtnText = submitBtn.innerHTML;

            // Disable button and show loading
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="bi bi-hourglass-split"></i> Saving...';

            let endpoint = isEditMode ? '../crud/update_subjects.php' : '../crud/add_subjects.php';

            fetch(endpoint, {
                    method: 'POST',
                    body: formData
                })
                .then(res => res.json())
                .then(data => {
                    if (data.success) {
                        Toast.fire({
                            icon: 'success',
                            title: data.message
                        });

                        resetForm();

                        // Reload page after short delay
                        setTimeout(() => {
                            location.reload();
                        }, 1000);
                    } else {
                        Swal.fire({
                            icon: 'error',
                            title: 'Error!',
                            text: data.message,
                            background: '#1a1a2e',
                            color: '#fff',
                            showConfirmButton: false,
                            timer: 3000,
                        });
                    }

                    // Re-enable button
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalBtnText;
                })
                .catch(error => {
                    Swal.fire({
                        icon: 'error',
                        title: 'Error!',
                        text: 'An error occurred. Please try again.',
                        background: '#1a1a2e',
                        color: '#fff',
                        showConfirmButton: false,
                        timer: 3000,
                    });
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalBtnText;
                });
        });

        // Edit button functionality
        document.addEventListener('click', function(e) {
            if (e.target.closest('.edit-btn')) {
                let btn = e.target.closest('.edit-btn');
                let subjectId = btn.getAttribute('data-id');
                let subjectCode = btn.getAttribute('data-code');
                let subjectName = btn.getAttribute('data-name');

                // Populate form
                document.getElementById('subjectId').value = subjectId;
                document.getElementById('subjectCode').value = subjectCode;
                document.getElementById('subjectName').value = subjectName;

                // Change form title and button
                document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil-square"></i> Edit Subject';
                document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-circle"></i> Update Subject';
                document.getElementById('cancelBtn').style.display = 'block';

                isEditMode = true;

                // Scroll to form
                document.querySelector('.card-custom').scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });

        // Cancel edit button
        document.getElementById('cancelBtn').addEventListener('click', function() {
            resetForm();
        });

        // Reset form function
        function resetForm() {
            document.getElementById('addSubjectForm').reset();
            document.getElementById('subjectId').value = '';
            document.getElementById('formTitle').innerHTML = '<i class="bi bi-plus-circle-fill"></i> Add New Subject';
            document.getElementById('submitBtn').innerHTML = '<i class="bi bi-save"></i> Save Subject';
            document.getElementById('cancelBtn').style.display = 'none';
            isEditMode = false;
        }

        // Delete button functionality
        document.addEventListener('click', function(e) {
            if (e.target.closest('.delete-btn')) {
                let btn = e.target.closest('.delete-btn');
                let subjectId = btn.getAttribute('data-id');
                let subjectCode = btn.getAttribute('data-code');

                Swal.fire({
                    title: 'Are you sure?',
                    html: `You are about to delete subject <strong>"${subjectCode}"</strong>.<br>This action cannot be undone!`,
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: '#f5576c',
                    cancelButtonColor: '#6c757d',
                    confirmButtonText: 'Yes, delete it!',
                    cancelButtonText: 'Cancel',
                    background: '#1a1a2e',
                    color: '#fff'
                }).then((result) => {
                    if (result.isConfirmed) {
                        // Show loading
                        Swal.fire({
                            title: 'Deleting...',
                            html: 'Please wait',
                            allowOutsideClick: false,
                            background: '#1a1a2e',
                            color: '#fff',
                            didOpen: () => {
                                Swal.showLoading();
                            }
                        });

                        // Delete subject
                        let formData = new FormData();
                        formData.append('subject_id', subjectId);

                        fetch('../crud/delete_subjects.php', {
                                method: 'POST',
                                body: formData
                            })
                            .then(res => res.json())
                            .then(data => {
                                if (data.success) {
                                    Swal.fire({
                                        icon: 'success',
                                        title: 'Deleted!',
                                        text: data.message,
                                        background: '#1a1a2e',
                                        color: '#fff',
                                        showConfirmButton: false,
                                        timer: 2000,
                                    }).then(() => {
                                        location.reload();
                                    });
                                } else {
                                    Swal.fire({
                                        icon: 'error',
                                        title: 'Error!',
                                        text: data.message,
                                        background: '#1a1a2e',
                                        color: '#fff',
                                        showConfirmButton: false,
                                        timer: 3000,
                                    });
                                }
                            })
                            .catch(error => {
                                Swal.fire({
                                    icon: 'error',
                                    title: 'Error!',
                                    text: 'An error occurred. Please try again.',
                                    background: '#1a1a2e',
                                    color: '#fff',
                                    showConfirmButton: false,
                                    timer: 3000,
                                });
                            });
                    }
                });
            }
        });
    </script>
</body>

</html>