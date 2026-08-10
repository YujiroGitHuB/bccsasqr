<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if (!isAdmin()) {
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lock_status'])) {
    $newStatus = $_POST['lock_status'];
    $stmt = $conn->prepare("UPDATE lock_settings_tbl SET setting_value = ? WHERE setting_key = 'page_locked'");
    $stmt->bind_param("s", $newStatus);
    $update = $stmt->execute();

    if ($update) {
        echo json_encode(['success' => true, 'status' => $newStatus]);
    } else {
        echo json_encode(['success' => false, 'error' => $stmt->error]);
    }
    exit;
}

// Get current lock status
$result = mysqli_query($conn, "SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked'");
$current = mysqli_fetch_assoc($result)['setting_value'];
$isLocked = ($current === 'true');

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
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <!-- SweetAlert2 CSS -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="page-header">
            <h2>Manage Subject Assignment</h2>
        </div>

        <div class="row">
            <!-- LEFT PANEL: ASSIGN FORM -->
            <div class="col-lg-4 col-md-12 mb-4">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-person-plus-fill"></i>
                        <h4 id="formTitle">Assign Instructor</h4>
                    </div>

                    <form id="assignSubjectInstructorForm">
                        <input type="hidden" id="assignmentId" name="assignment_id">

                        <div class="mb-3">
                            <label class="form-label">
                                <i class="bi bi-book"></i> Select Subject
                            </label>
                            <select name="subject_id" id="subjectSelect" class="form-select" required>
                                <option value="">-- Choose Subject --</option>
                                <?php
                                $subjects = mysqli_query($conn, "SELECT id, subject_code, subject_name FROM subjects_tbl ORDER BY subject_name");
                                while ($s = mysqli_fetch_assoc($subjects)) {
                                    echo "<option value='{$s['id']}'>{$s['subject_code']} - {$s['subject_name']}</option>";
                                }
                                ?>
                            </select>
                        </div>

                        <div class="mb-3">
                            <label class="form-label">
                                <i class="bi bi-person"></i> Select Instructor
                            </label>
                            <select name="instructor_id" id="instructorSelect" class="form-select" required>
                                <option value="">-- Choose Instructor --</option>
                                <?php
                                $inst = mysqli_query($conn, "SELECT id, name, role FROM users WHERE role IN ('admin','instructor') ORDER BY name");
                                while ($i = mysqli_fetch_assoc($inst)) {
                                    $roleLabel = ucfirst($i['role']);
                                    echo "<option value='{$i['id']}'>{$i['name']} ({$roleLabel})</option>";
                                }
                                ?>
                            </select>
                        </div>

                        <button type="submit" class="btn btn-primary w-100" id="submitBtn">
                            <i class="bi bi-check-circle"></i> Assign Instructor
                        </button>

                        <button type="button" class="btn btn-secondary w-100 mt-2" id="cancelBtn" style="display: none;">
                            <i class="bi bi-x-circle"></i> Cancel
                        </button>
                    </form>
                </div>
            </div>

            <!-- RIGHT PANEL: ASSIGNMENTS TABLE -->
            <div class="col-lg-8 col-md-12">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-table"></i>
                        <h4>Assignment List</h4>
                        <span class="badge-count ms-auto" id="assignmentCount">
                            <?php
                            $countQuery = mysqli_query($conn, "SELECT COUNT(*) as total FROM subject_instructors_tbl");
                            $count = mysqli_fetch_assoc($countQuery)['total'];
                            echo $count . ' ' . ($count == 1 ? 'Assignment' : 'Assignments');
                            ?>
                        </span>
                    </div>

                    <div class="table-wrapper">
                        <div class="table-responsive">
                            <table class="table table-dark table-hover" id="assignmentTable">
                                <thead>
                                    <tr>
                                        <th style="width: 60px;">#</th>
                                        <th>Subject</th>
                                        <th>Instructor</th>
                                        <th style="width: 180px;">Action</th>
                                    </tr>
                                </thead>
                                <tbody id="assignmentTableBody">
                                    <?php
                                    $assignments = mysqli_query($conn, "
                                        SELECT 
                                            si.id,
                                            si.subject_id,
                                            si.instructor_id,
                                            s.subject_code,
                                            s.subject_name,
                                            u.name as instructor_name
                                        FROM subject_instructors_tbl si
                                        JOIN subjects_tbl s ON si.subject_id = s.id
                                        JOIN users u ON si.instructor_id = u.id
                                        ORDER BY s.subject_code ASC
                                    ");

                                    if (mysqli_num_rows($assignments) > 0) {
                                        $i = 1;
                                        while ($row = mysqli_fetch_assoc($assignments)) {
                                    ?>
                                            <tr>
                                                <td><?= $i++ ?></td>
                                                <td>
                                                    <span class="badge-subject">
                                                        <?= htmlspecialchars($row['subject_code']) ?>
                                                    </span><br>
                                                    <small><?= htmlspecialchars($row['subject_name']) ?></small>
                                                </td>
                                                <td>
                                                    <span class="badge-instructor">
                                                        <i class="bi bi-person"></i> <?= htmlspecialchars($row['instructor_name']) ?>
                                                    </span>
                                                </td>
                                                <td>
                                                    <button
                                                        class="btn btn-sm btn-success edit-btn"
                                                        data-id="<?= $row['id'] ?>"
                                                        data-subject-id="<?= $row['subject_id'] ?>"
                                                        data-instructor-id="<?= $row['instructor_id'] ?>"
                                                        data-subject="<?= htmlspecialchars($row['subject_code']) ?>"
                                                        data-instructor="<?= htmlspecialchars($row['instructor_name']) ?>">
                                                        <i class="bi bi-pencil"></i>
                                                    </button>
                                                    <button
                                                        class="btn btn-sm btn-danger delete-btn"
                                                        data-id="<?= $row['id'] ?>"
                                                        data-subject="<?= htmlspecialchars($row['subject_code']) ?>"
                                                        data-instructor="<?= htmlspecialchars($row['instructor_name']) ?>">
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

    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>

    <script>
        let isEditMode = false;

        // Configure SweetAlert2 dark theme
        const Toast = Swal.mixin({
            toast: true,
            position: 'top-end',
            showConfirmButton: false,
            timer: 1500,
            timerProgressBar: true,
            background: '#1a1a2e',
            color: '#fff',
            didOpen: (toast) => {
                toast.addEventListener('mouseenter', Swal.stopTimer)
                toast.addEventListener('mouseleave', Swal.resumeTimer)
            }
        });

        // Assign/Update form submission
        document.getElementById('assignSubjectInstructorForm').addEventListener('submit', function(e) {
            e.preventDefault();

            let formData = new FormData(this);
            let submitBtn = document.getElementById('submitBtn');
            let originalBtnText = submitBtn.innerHTML;

            // Disable button and show loading
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="bi bi-hourglass-split"></i> Processing...';

            let endpoint = isEditMode ? '../crud/update_assignment.php' : '../crud/assign_subject_instructor.php';

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
                            timer: 1500,
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
                        timer: 1500,
                    });
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalBtnText;
                });
        });

        // Edit button functionality
        document.addEventListener('click', function(e) {
            if (e.target.closest('.edit-btn')) {
                let btn = e.target.closest('.edit-btn');
                let assignmentId = btn.getAttribute('data-id');
                let subjectId = btn.getAttribute('data-subject-id');
                let instructorId = btn.getAttribute('data-instructor-id');
                let subjectName = btn.getAttribute('data-subject');
                let instructorName = btn.getAttribute('data-instructor');

                // Populate form
                document.getElementById('assignmentId').value = assignmentId;
                document.getElementById('subjectSelect').value = subjectId;
                document.getElementById('instructorSelect').value = instructorId;

                // Change form title and button
                document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil-square"></i> Edit Assignment';
                document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-circle"></i> Update Assignment';
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
            document.getElementById('assignSubjectInstructorForm').reset();
            document.getElementById('assignmentId').value = '';
            document.getElementById('formTitle').innerHTML = '<i class="bi bi-person-plus-fill"></i> Assign Instructor';
            document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-circle"></i> Assign Instructor';
            document.getElementById('cancelBtn').style.display = 'none';
            isEditMode = false;
        }

        // Delete button functionality
        document.addEventListener('click', function(e) {
            if (e.target.closest('.delete-btn')) {
                let btn = e.target.closest('.delete-btn');
                let assignmentId = btn.getAttribute('data-id');
                let subjectName = btn.getAttribute('data-subject');
                let instructorName = btn.getAttribute('data-instructor');

                Swal.fire({
                    title: 'Are you sure?',
                    html: `You are about to remove the assignment:<br><br>
                           <strong>Subject:</strong> ${subjectName}<br>
                           <strong>Instructor:</strong> ${instructorName}<br><br>
                           This action cannot be undone!`,
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

                        // Delete assignment
                        let formData = new FormData();
                        formData.append('assignment_id', assignmentId);

                        fetch('../crud/delete_assignment.php', {
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
                                        timer: 1500,
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
                                        timer: 1500,
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
                                    timer: 1500,
                                });
                            });
                    }
                });
            }
        });
    </script>
</body>

</html>