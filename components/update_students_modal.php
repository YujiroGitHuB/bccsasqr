<?php
// Fetch unique sections from database for edit modal
$query_edit = "SELECT DISTINCT section FROM students_tbl WHERE section IS NOT NULL AND section != '' ORDER BY section ASC";
$result_edit = mysqli_query($conn, $query_edit);
?>

<!-- Edit Student Modal -->
<div class="modal fade" id="editModal" tabindex="-1" aria-labelledby="editModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 rounded-4 shadow-lg" style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fs-4 fw-bold text-white" id="editModalLabel">
                    <span class="badge rounded-pill px-3 py-2" style="background: linear-gradient(90deg, #10a824, #0b5e15);">
                        <i class="bi bi-pencil-square"></i> Edit Student
                    </span>
                </h5>
                <button type="button" class="btn-close btn-close-white opacity-75" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <form id="updateStudentForm" class="needs-validation" novalidate>
                    <input type="hidden" name="id" id="edit_id">

                    <!-- Student Number -->
                    <div class="mb-4">
                        <label for="edit_student_no" class="form-label text-white-50 fw-semibold mb-2">
                            <i class="bi bi-person-badge text-success"></i> Student Number
                        </label>
                        <div class="input-group input-group-lg">
                            <span class="input-group-text bg-dark border-0 text-success">
                                <i class="bi bi-hash"></i>
                            </span>
                            <input type="text" 
                                   class="form-control bg-dark text-white border-0 shadow-sm" 
                                   id="edit_student_no" 
                                   name="student_no" 
                                   placeholder="Enter student number"
                                  style="border-left: 3px solid #28a745 !important;"
                                   required>
                        </div>
                    </div>

                    <!-- Full Name -->
                    <div class="mb-4">
                        <label for="edit_fullname" class="form-label text-white-50 fw-semibold mb-2">
                            <i class="bi bi-person-fill text-success"></i> Full Name
                        </label>
                        <div class="input-group input-group-lg">
                            <span class="input-group-text bg-dark border-0 text-success">
                                <i class="bi bi-pencil-fill"></i>
                            </span>
                            <input type="text" 
                                   class="form-control bg-dark text-white border-0 shadow-sm" 
                                   id="edit_fullname" 
                                   name="fullname" 
                                   placeholder="Enter full name"
                                   style="border-left: 3px solid #28a745 !important;"
                                   required>
                        </div>
                    </div>

                    <!-- Course and Section Row -->
                    <div class="row g-3 mb-4">
                        <!-- Course -->
                        <div class="col-md-6">
                            <label for="edit_course" class="form-label text-white-50 fw-semibold mb-2">
                                <i class="bi bi-book-fill text-success"></i> Course
                            </label>
                            <div class="input-group input-group-lg">
                                <span class="input-group-text bg-dark border-0 text-success">
                                    <i class="bi bi-mortarboard-fill"></i>
                                </span>
                                <select class="form-select bg-dark text-white border-0 shadow-sm" 
                                        id="edit_course" 
                                        name="course" 
                                       style="border-left: 3px solid #28a745 !important;"
                                        required>
                                    <option value="" disabled>Select Course</option>
                                    <option value="BSIT">BSIT</option>
                                    <option value="BEED">BEED</option>
                                </select>
                            </div>
                        </div>

                        <!-- Section -->
                        <div class="col-md-6">
                            <label for="edit_section" class="form-label text-white-50 fw-semibold mb-2">
                                <i class="bi bi-grid-3x3-gap-fill text-success"></i> Section
                            </label>
                            <div class="input-group input-group-lg">
                                <span class="input-group-text bg-dark border-0 text-success">
                                    <i class="bi bi-collection-fill"></i>
                                </span>
                                <select class="form-select bg-dark text-white border-0 shadow-sm" 
                                        id="edit_section" 
                                        name="section" 
                                       style="border-left: 3px solid #28a745 !important;"
                                        required>
                                    <option value="" disabled>Select Section</option>
                                    <?php
                                    if ($result_edit && mysqli_num_rows($result_edit) > 0) {
                                        while ($row = mysqli_fetch_assoc($result_edit)) {
                                            echo '<option value="' . htmlspecialchars($row['section']) . '">' . htmlspecialchars($row['section']) . '</option>';
                                        }
                                    }
                                    ?>
                                </select>
                            </div>
                        </div>
                    </div>

                    <!-- Submit Button -->
                    <div class="d-grid gap-2 mt-4">
                        <button type="submit" class="btn btn-lg fw-bold text-white py-3 rounded-3 shadow-lg btn-update-student">
                            <i class="bi bi-check-circle-fill me-2"></i> Save Changes
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>