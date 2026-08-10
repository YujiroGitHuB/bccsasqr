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

// Get current system configuration
$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);
$systemName    = $system['system_name']    ?? '';
$systemAcronym = $system['system_acronym'] ?? '';
$systemLogo    = $system['logo']           ?? '';

// Hero chips + badge sa card header — isang query kada bilang.
$assignmentTotal = (int) (mysqli_fetch_assoc(
    mysqli_query($conn, "SELECT COUNT(*) as total FROM instructor_section_tbl")
)['total'] ?? 0);

$coveredSections = (int) (mysqli_fetch_assoc(
    mysqli_query($conn, "SELECT COUNT(DISTINCT CONCAT(course,'-',section)) as total FROM instructor_section_tbl")
)['total'] ?? 0);

$allSections = (int) (mysqli_fetch_assoc(
    mysqli_query($conn, "SELECT COUNT(DISTINCT CONCAT(course,'-',section)) as total FROM students_tbl")
)['total'] ?? 0);
?>

<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/academic-pages.css') ?>">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content acad-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="acad-hero">
            <div class="acad-hero-icon"><i class="bi bi-diagram-3-fill"></i></div>
            <div class="acad-hero-text">
                <h2>Sections</h2>
                <p>Which sections each instructor covers. This limits the students they can see.</p>
            </div>
            <div class="acad-hero-meta">
                <span class="acad-chip">
                    <i class="bi bi-link-45deg"></i>
                    <?= $assignmentTotal ?> <?= $assignmentTotal === 1 ? 'Assignment' : 'Assignments' ?>
                </span>
                <span class="acad-chip <?= ($allSections > 0 && $coveredSections >= $allSections) ? 'green' : 'amber' ?>">
                    <i class="bi bi-grid-3x3-gap"></i>
                    <?= $coveredSections ?>/<?= $allSections ?> sections covered
                </span>
            </div>
        </div>

        <div class="row">
            <!-- LEFT PANEL: ASSIGN FORM -->
            <!-- Walang acad-sticky dito: mataas ang form (checkbox grid
                 ng mga section), kaya hindi na kasya sa screen kapag
                 idinikit sa itaas. -->
            <div class="col-lg-4 col-md-12 mb-4">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <i class="bi bi-clipboard-plus"></i>
                        <h4 id="formTitle">Assign Sections</h4>
                    </div>

                    <form id="assignSectionForm" method="post">
                        <input type="hidden" id="assignmentId" name="assignment_id">

                        <!-- Current Assignment Info Card (Edit Mode Only) -->
                        <div id="currentAssignmentCard" class="current-assignment-card" style="display: none;">
                            <div class="current-assignment-header">
                                <i class="bi bi-info-circle-fill"></i> Currently Editing
                            </div>
                            <div class="current-assignment-body">
                                <div class="current-item">
                                    <span class="label"><i class="bi bi-grid-3x3"></i> Section:</span>
                                    <span class="value badge-section-sm" id="currentSectionValue">-</span>
                                </div>
                                <div class="current-item">
                                    <span class="label"><i class="bi bi-person"></i> Instructor:</span>
                                    <span class="value badge-instructor-sm" id="currentInstructorValue">-</span>
                                </div>
                            </div>
                            <div class="current-assignment-note">
                                <i class="bi bi-lightbulb-fill"></i>
                                <span>You can change the instructor and/or section below</span>
                            </div>
                        </div>

                        <div class="mb-3">
                            <label class="form-label">
                                <i class="bi bi-person"></i> <span id="instructorLabelText">Select Instructor</span>
                            </label>
                            <select id="instructor_id" name="instructor_id" class="form-select" required>
                                <option value="">-- Choose Instructor --</option>
                                <?php
                                $instructors = mysqli_query($conn, "SELECT id, name, role FROM users WHERE role IN ('instructor', 'admin') ORDER BY role DESC, name");
                                while ($i = mysqli_fetch_assoc($instructors)) {
                                    $badge = $i['role'] === 'admin' ? ' [Admin]' : ' [Instructor]';
                                    echo "<option value='{$i['id']}'>{$i['name']}{$badge}</option>";
                                }
                                ?>
                            </select>
                        </div>

                        <div class="mb-3">
                            <!-- Checkbox Mode (for new assignments) -->
                            <div id="checkboxMode">
                                <div class="form-section-header">
                                    <label class="form-label">
                                        <i class="bi bi-grid-3x3-gap-fill"></i> Select Sections
                                    </label>
                                    <span class="selected-count" id="selectedCount">
                                        <i class="bi bi-check-circle-fill"></i> 0 selected
                                    </span>
                                </div>

                                <!-- Search Bar -->
                                <div class="section-search-wrapper">
                                    <i class="bi bi-search"></i>
                                    <input type="text" id="sectionSearch" class="section-search-input" placeholder="Search sections...">
                                    <button type="button" id="clearSearch" class="clear-search-btn" style="display: none;">
                                        <i class="bi bi-x-circle-fill"></i>
                                    </button>
                                </div>

                                <div class="section-checkbox-wrapper">
                                    <!-- Select All -->
                                    <div class="select-all-wrapper">
                                        <div class="custom-checkbox-container">
                                            <input type="checkbox" id="selectAll" class="custom-checkbox-input" />
                                            <label for="selectAll" class="custom-checkbox-label">
                                                <span class="checkbox-box"><i class="bi bi-check2"></i></span>
                                                <span class="checkbox-text">
                                                    <i class="bi bi-check-all"></i> Select All Sections
                                                </span>
                                            </label>
                                        </div>
                                    </div>

                                    <!-- Sections List grouped by course -->
                                    <div id="sectionCheckboxes" class="sections-grid">
                                        <?php
                                        // ✅ UPDATED: Get full_section = CONCAT(course, '-', section)
                                        // Grouped by course para mas organized
                                        $sections_q = mysqli_query($conn, "
                                            SELECT DISTINCT course, section,
                                                   CONCAT(course, '-', section) as full_section
                                            FROM students_tbl
                                            ORDER BY course, section
                                        ");

                                        $grouped = [];
                                        while ($s = mysqli_fetch_assoc($sections_q)) {
                                            $grouped[$s['course']][] = $s;
                                        }

                                        foreach ($grouped as $course => $secs):
                                            $courseSlug = str_replace(' ', '_', $course);
                                        ?>
                                            <!-- Course Group Header -->
                                            <div class="section-group-header" style="
                                                font-size:.72rem; font-weight:700; text-transform:uppercase;
                                                letter-spacing:1px; color:#667eea;
                                                padding:6px 10px 3px;
                                                background:rgba(102,126,234,.08);
                                                border-top:1px solid rgba(102,126,234,.2);
                                                margin-top:4px;">
                                                <i class="bi bi-mortarboard me-1"></i><?= htmlspecialchars($course) ?>
                                            </div>

                                            <?php foreach ($secs as $s):
                                                $fullSection = htmlspecialchars($s['full_section']);
                                                $sectionId   = 'section_' . str_replace([' ', '-'], '_', $s['full_section']);
                                            ?>
                                            <div class="section-checkbox-item"
                                                data-section-name="<?= strtolower($fullSection) ?>">
                                                <div class="custom-checkbox-container">
                                                    <!-- ✅ value = full_section (e.g. "BSIT-1A") -->
                                                    <input type="checkbox"
                                                        name="sections[]"
                                                        value="<?= $fullSection ?>"
                                                        id="<?= $sectionId ?>"
                                                        class="custom-checkbox-input section-checkbox">
                                                    <label for="<?= $sectionId ?>" class="custom-checkbox-label">
                                                        <span class="checkbox-box"><i class="bi bi-check2"></i></span>
                                                        <span class="checkbox-text">
                                                            <i class="bi bi-grid-3x3"></i> <?= $fullSection ?>
                                                        </span>
                                                    </label>
                                                </div>
                                            </div>
                                            <?php endforeach; ?>
                                        <?php endforeach; ?>
                                    </div>

                                    <!-- No Results Message -->
                                    <div id="noResultsMessage" class="no-results-message" style="display: none;">
                                        <i class="bi bi-inbox"></i>
                                        <p>No sections found</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Dropdown Mode (for editing single assignment) -->
                            <div id="dropdownMode" style="display: none;">
                                <label class="form-label">
                                    <i class="bi bi-grid-3x3"></i> Change Section
                                    <small class="text-muted">(optional)</small>
                                </label>
                                <select id="sectionDropdown" name="section" class="form-select">
                                    <option value="">-- Choose Section --</option>
                                    <?php
                                    // ✅ UPDATED: full_section as value
                                    foreach ($grouped as $course => $secs):
                                        echo "<optgroup label='" . htmlspecialchars($course) . "'>";
                                        foreach ($secs as $s):
                                            $full = htmlspecialchars($s['full_section']);
                                            echo "<option value='{$full}'>{$full}</option>";
                                        endforeach;
                                        echo "</optgroup>";
                                    endforeach;
                                    ?>
                                </select>
                                <small class="text-muted">
                                    <i class="bi bi-info-circle"></i> You can change the section or keep it the same
                                </small>
                            </div>
                        </div>

                        <button type="submit" class="btn btn-primary w-100" id="submitBtn">
                            <i class="bi bi-check-circle"></i> Assign Sections
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
                        <h4>Section Assignments</h4>
                        <span class="badge-count ms-auto" id="assignmentCount">
                            <?= $assignmentTotal ?> <?= $assignmentTotal === 1 ? 'Assignment' : 'Assignments' ?>
                        </span>
                    </div>

                    <!-- Bulk Action Bar -->
                    <div id="bulkActionBar" class="bulk-action-bar" style="display: none;">
                        <div class="bulk-action-content">
                            <span class="bulk-selected-count">
                                <i class="bi bi-check-square-fill"></i>
                                <span id="bulkSelectedCount">0</span> selected
                            </span>
                            <button type="button" class="btn btn-danger btn-sm" id="bulkDeleteBtn">
                                <i class="bi bi-trash-fill"></i> Delete Selected
                            </button>
                            <button type="button" class="btn btn-secondary btn-sm" id="bulkCancelBtn">
                                <i class="bi bi-x-lg"></i> Cancel
                            </button>
                        </div>
                    </div>

                    <div class="table-wrapper">
                        <div class="table-responsive">
                            <table class="table table-dark table-hover" id="assignmentTable">
                                <thead>
                                    <tr>
                                        <th style="width: 50px;">
                                            <div class="table-checkbox-container">
                                                <input type="checkbox" id="selectAllAssignments" class="table-checkbox-input">
                                                <label for="selectAllAssignments" class="table-checkbox-label">
                                                    <span class="table-checkbox-box"><i class="bi bi-check2"></i></span>
                                                </label>
                                            </div>
                                        </th>
                                        <th style="width: 60px;">#</th>
                                        <th style="width: 200px;">Course</th>
                                        <th style="width: 200px;">Section</th>
                                        <th>Instructor</th>
                                        <th style="width: 180px;">Action</th>
                                    </tr>
                                </thead>
                                <tbody id="assignmentTableBody">
                                    <?php
                                    // ✅ section column already stores full_section after migration
                                    $assignments = mysqli_query($conn, "
                                        SELECT
                                            si.id,
                                            si.section,
                                            si.course,
                                            si.instructor_id,
                                            u.name as instructor_name
                                        FROM instructor_section_tbl si
                                        JOIN users u ON si.instructor_id = u.id
                                        ORDER BY si.section ASC
                                    ");

                                    // Ang mensahe kapag walang laman ay hawak ng
                                    // DataTables (assets/js/datatables.js).
                                    if (mysqli_num_rows($assignments) > 0):
                                        $i = 1;
                                        while ($row = mysqli_fetch_assoc($assignments)):
                                    ?>
                                    <tr>
                                        <td>
                                            <div class="table-checkbox-container">
                                                <input type="checkbox"
                                                    id="assign_<?= $row['id'] ?>"
                                                    class="table-checkbox-input assignment-checkbox"
                                                    data-id="<?= $row['id'] ?>"
                                                    data-section="<?= htmlspecialchars($row['section']) ?>"
                                                    data-instructor="<?= htmlspecialchars($row['instructor_name']) ?>">
                                                <label for="assign_<?= $row['id'] ?>" class="table-checkbox-label">
                                                    <span class="table-checkbox-box"><i class="bi bi-check2"></i></span>
                                                </label>
                                            </div>
                                        </td>
                                        <td><?= $i++ ?></td>
                                        <td>
                                            <span class="badge-section">
                                                <i class="bi bi-grid-3x3"></i>
                                                <?= htmlspecialchars($row['course']) ?>
                                            </span>
                                        </td>
                                        <td>
                                            <span class="badge-section">
                                                <i class="bi bi-grid-3x3"></i>
                                                <?= htmlspecialchars($row['section']) ?>
                                            </span>
                                        </td>
                                        <td>
                                            <span class="badge-instructor">
                                                <i class="bi bi-person"></i>
                                                <?= htmlspecialchars($row['instructor_name']) ?>
                                            </span>
                                        </td>
                                        <td>
                                            <button class="btn btn-sm btn-success edit-btn"
                                                data-id="<?= $row['id'] ?>"
                                                data-section="<?= htmlspecialchars($row['section']) ?>"
                                                data-instructor-id="<?= $row['instructor_id'] ?>"
                                                data-instructor="<?= htmlspecialchars($row['instructor_name']) ?>">
                                                <i class="bi bi-pencil"></i>
                                            </button>
                                            <button class="btn btn-sm btn-danger delete-btn"
                                                data-id="<?= $row['id'] ?>"
                                                data-section="<?= htmlspecialchars($row['section']) ?>"
                                                data-instructor="<?= htmlspecialchars($row['instructor_name']) ?>">
                                                <i class="bi bi-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                    <?php endwhile; endif; ?>
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

    <script>
        let isEditMode = false;

        const Toast = Swal.mixin({
            toast: true,
            position: 'top-end',
            showConfirmButton: false,
            timer: 1500,
            timerProgressBar: true,
            background: '#1a1a2e',
            color: '#fff',
            didOpen: (toast) => {
                toast.addEventListener('mouseenter', Swal.stopTimer);
                toast.addEventListener('mouseleave', Swal.resumeTimer);
            }
        });

        // Search Functionality
        document.getElementById('sectionSearch').addEventListener('input', function () {
            const searchTerm = this.value.toLowerCase().trim();
            const clearBtn = document.getElementById('clearSearch');
            const sectionItems = document.querySelectorAll('.section-checkbox-item');
            const noResultsMsg = document.getElementById('noResultsMessage');
            let visibleCount = 0;

            clearBtn.style.display = searchTerm ? 'block' : 'none';

            sectionItems.forEach(item => {
                const sectionName = item.getAttribute('data-section-name');
                const match = sectionName.includes(searchTerm);
                item.style.display = match ? 'block' : 'none';
                if (match) visibleCount++;
            });

            // Hide course group headers if no visible items under them
            document.querySelectorAll('.section-group-header').forEach(header => {
                let next = header.nextElementSibling;
                let hasVisible = false;
                while (next && !next.classList.contains('section-group-header')) {
                    if (next.classList.contains('section-checkbox-item') && next.style.display !== 'none') {
                        hasVisible = true;
                    }
                    next = next.nextElementSibling;
                }
                header.style.display = hasVisible ? 'block' : 'none';
            });

            noResultsMsg.style.display = visibleCount === 0 ? 'block' : 'none';
        });

        document.getElementById('clearSearch').addEventListener('click', function () {
            document.getElementById('sectionSearch').value = '';
            document.getElementById('sectionSearch').dispatchEvent(new Event('input'));
            document.getElementById('sectionSearch').focus();
        });

        function updateSelectedCount() {
            const count = document.querySelectorAll('.section-checkbox:checked').length;
            document.getElementById('selectedCount').innerHTML =
                `<i class="bi bi-check-circle-fill"></i> ${count} selected`;
        }

        document.getElementById('selectAll').addEventListener('change', function () {
            const visibleCheckboxes = Array.from(document.querySelectorAll('.section-checkbox')).filter(cb =>
                cb.closest('.section-checkbox-item').style.display !== 'none'
            );
            visibleCheckboxes.forEach(cb => cb.checked = this.checked);
            updateSelectedCount();
        });

        document.querySelectorAll('.section-checkbox').forEach(checkbox => {
            checkbox.addEventListener('change', function () {
                updateSelectedCount();
                const all = Array.from(document.querySelectorAll('.section-checkbox')).filter(cb =>
                    cb.closest('.section-checkbox-item').style.display !== 'none'
                );
                const checked = all.filter(cb => cb.checked);
                document.getElementById('selectAll').checked = all.length > 0 && all.length === checked.length;
            });
        });

        // Form submission
        document.getElementById('assignSectionForm').addEventListener('submit', function (e) {
            e.preventDefault();

            if (isEditMode) {
                if (!document.getElementById('sectionDropdown').value) {
                    Swal.fire({ icon: 'warning', title: 'Section Required', text: 'Please select a section.', background: '#1a1a2e', color: '#fff', confirmButtonColor: '#4ecca3' });
                    return;
                }
            } else {
                if (document.querySelectorAll('.section-checkbox:checked').length === 0) {
                    Swal.fire({ icon: 'warning', title: 'No Sections Selected', text: 'Please select at least one section.', background: '#1a1a2e', color: '#fff', confirmButtonColor: '#4ecca3' });
                    return;
                }
            }

            const formData = new FormData(this);
            const submitBtn = document.getElementById('submitBtn');
            const originalBtnText = submitBtn.innerHTML;

            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="bi bi-hourglass-split"></i> Processing...';

            const endpoint = isEditMode ? '../crud/update_section_assignment.php' : '../includes/assign_sections_bulk.php';

            fetch(endpoint, { method: 'POST', body: formData })
                .then(res => res.json())
                .then(data => {
                    if (data.success) {
                        Toast.fire({ icon: 'success', title: data.message });
                        resetForm();
                        setTimeout(() => location.reload(), 1000);
                    } else {
                        Swal.fire({ icon: 'error', title: 'Error!', text: data.message, background: '#1a1a2e', color: '#fff', confirmButtonColor: '#f5576c' });
                    }
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalBtnText;
                })
                .catch(() => {
                    Swal.fire({ icon: 'error', title: 'Error!', text: 'An error occurred.', background: '#1a1a2e', color: '#fff', confirmButtonColor: '#f5576c' });
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = originalBtnText;
                });
        });

        // Edit button
        document.addEventListener('click', function (e) {
            if (e.target.closest('.edit-btn')) {
                const btn = e.target.closest('.edit-btn');

                document.getElementById('currentAssignmentCard').style.display = 'block';
                document.getElementById('currentSectionValue').textContent = btn.dataset.section;
                document.getElementById('currentInstructorValue').textContent = btn.dataset.instructor;
                document.getElementById('instructorLabelText').innerHTML = 'Change Instructor <small class="text-muted">(optional)</small>';

                document.getElementById('assignmentId').value = btn.dataset.id;
                document.getElementById('instructor_id').value = btn.dataset.instructorId;

                document.getElementById('checkboxMode').style.display = 'none';
                document.getElementById('dropdownMode').style.display = 'block';
                document.getElementById('sectionDropdown').value = btn.dataset.section;
                document.getElementById('sectionDropdown').required = true;

                document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil-square"></i> Edit Assignment';
                document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-circle"></i> Update Assignment';
                document.getElementById('cancelBtn').style.display = 'block';

                isEditMode = true;

                document.querySelector('.card-custom').scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });

        document.getElementById('cancelBtn').addEventListener('click', resetForm);

        function resetForm() {
            document.getElementById('assignSectionForm').reset();
            document.getElementById('assignmentId').value = '';
            document.getElementById('formTitle').innerHTML = '<i class="bi bi-clipboard-plus"></i> Assign Sections';
            document.getElementById('submitBtn').innerHTML = '<i class="bi bi-check-circle"></i> Assign Sections';
            document.getElementById('cancelBtn').style.display = 'none';
            document.getElementById('currentAssignmentCard').style.display = 'none';
            document.getElementById('instructorLabelText').textContent = 'Select Instructor';
            document.getElementById('checkboxMode').style.display = 'block';
            document.getElementById('dropdownMode').style.display = 'none';
            document.getElementById('sectionDropdown').required = false;
            document.getElementById('selectAll').checked = false;
            document.querySelectorAll('.section-checkbox').forEach(cb => cb.checked = false);
            document.getElementById('sectionSearch').value = '';
            document.getElementById('sectionSearch').dispatchEvent(new Event('input'));
            updateSelectedCount();
            isEditMode = false;
        }

        // Delete button
        document.addEventListener('click', function (e) {
            if (e.target.closest('.delete-btn')) {
                const btn = e.target.closest('.delete-btn');
                Swal.fire({
                    title: 'Are you sure?',
                    html: `Remove assignment:<br><br><strong>Section:</strong> ${btn.dataset.section}<br><strong>Instructor:</strong> ${btn.dataset.instructor}<br><br>This cannot be undone!`,
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: '#f5576c',
                    cancelButtonColor: '#6c757d',
                    confirmButtonText: 'Yes, delete it!',
                    background: '#1a1a2e', color: '#fff'
                }).then(result => {
                    if (!result.isConfirmed) return;
                    Swal.fire({ title: 'Deleting...', allowOutsideClick: false, background: '#1a1a2e', color: '#fff', didOpen: () => Swal.showLoading() });

                    const fd = new FormData();
                    fd.append('assignment_id', btn.dataset.id);
                    fetch('../crud/delete_section_assignment.php', { method: 'POST', body: fd })
                        .then(r => r.json())
                        .then(data => {
                            if (data.success) {
                                Swal.fire({ icon: 'success', title: 'Deleted!', text: data.message, background: '#1a1a2e', color: '#fff', showConfirmButton: false, timer: 1500 })
                                    .then(() => location.reload());
                            } else {
                                Swal.fire({ icon: 'error', title: 'Error!', text: data.message, background: '#1a1a2e', color: '#fff', confirmButtonColor: '#f5576c' });
                            }
                        });
                });
            }
        });

        // Table Select All
        document.getElementById('selectAllAssignments').addEventListener('change', function () {
            document.querySelectorAll('.assignment-checkbox').forEach(cb => cb.checked = this.checked);
            updateBulkActionBar();
        });

        document.querySelectorAll('.assignment-checkbox').forEach(checkbox => {
            checkbox.addEventListener('change', function () {
                updateBulkActionBar();
                const all = document.querySelectorAll('.assignment-checkbox');
                const checked = document.querySelectorAll('.assignment-checkbox:checked');
                document.getElementById('selectAllAssignments').checked = all.length === checked.length;
            });
        });

        function updateBulkActionBar() {
            const count = document.querySelectorAll('.assignment-checkbox:checked').length;
            document.getElementById('bulkActionBar').style.display = count > 0 ? 'block' : 'none';
            document.getElementById('bulkSelectedCount').textContent = count;
        }

        document.getElementById('bulkCancelBtn').addEventListener('click', function () {
            document.querySelectorAll('.assignment-checkbox').forEach(cb => cb.checked = false);
            document.getElementById('selectAllAssignments').checked = false;
            updateBulkActionBar();
        });

        document.getElementById('bulkDeleteBtn').addEventListener('click', function () {
            const checkedBoxes = document.querySelectorAll('.assignment-checkbox:checked');
            if (!checkedBoxes.length) return;

            let list = '<ul style="text-align:left;max-height:200px;overflow-y:auto;">';
            checkedBoxes.forEach(cb => {
                list += `<li><strong>${cb.dataset.section}</strong> - ${cb.dataset.instructor}</li>`;
            });
            list += '</ul>';

            Swal.fire({
                title: 'Delete Multiple Assignments?',
                html: `Deleting <strong>${checkedBoxes.length}</strong> assignment(s):<br><br>${list}<br>This cannot be undone!`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#f5576c',
                cancelButtonColor: '#6c757d',
                confirmButtonText: 'Yes, delete them!',
                background: '#1a1a2e', color: '#fff'
            }).then(result => {
                if (!result.isConfirmed) return;
                Swal.fire({ title: 'Deleting...', allowOutsideClick: false, background: '#1a1a2e', color: '#fff', didOpen: () => Swal.showLoading() });

                const ids = Array.from(checkedBoxes).map(cb => cb.dataset.id);
                const fd = new FormData();
                fd.append('assignment_ids', JSON.stringify(ids));

                fetch('../crud/delete_section_assignments_bulk.php', { method: 'POST', body: fd })
                    .then(r => r.json())
                    .then(data => {
                        if (data.success) {
                            Swal.fire({ icon: 'success', title: 'Deleted!', text: data.message, background: '#1a1a2e', color: '#fff', showConfirmButton: false, timer: 1500 })
                                .then(() => location.reload());
                        } else {
                            Swal.fire({ icon: 'error', title: 'Error!', text: data.message, background: '#1a1a2e', color: '#fff', confirmButtonColor: '#f5576c' });
                        }
                    });
            });
        });
    </script>
</body>
</html>