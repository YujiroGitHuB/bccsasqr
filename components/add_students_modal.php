<?php
// Fetch unique sections from database
$query = "SELECT DISTINCT section FROM students_tbl WHERE section IS NOT NULL AND section != '' ORDER BY section ASC";
$result = mysqli_query($conn, $query);
?>

<!-- Add Student Modal -->
<div class="modal fade" id="addStudentModal" tabindex="-1" aria-labelledby="addStudentLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 rounded-4 shadow-lg" style="background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fs-4 fw-bold text-white" id="addStudentLabel">
                    <span class="badge rounded-pill px-3 py-2" style="background: linear-gradient(90deg, #0575e6, #021b79);">
                        <i class="bi bi-person-plus-fill"></i> Add New Student
                    </span>
                </h5>
                <button type="button" class="btn-close btn-close-white opacity-75" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <form id="addStudentForm" class="needs-validation" novalidate>
                    <!-- Student Number -->
                    <div class="mb-4">
                        <label for="student_no" class="form-label text-white-50 fw-semibold mb-2">
                            <i class="bi bi-person-badge text-info"></i> Student Number
                        </label>
                        <div class="input-group input-group-lg">
                            <span class="input-group-text bg-dark border-0 text-info">
                                <i class="bi bi-hash"></i>
                            </span>
                            <input type="text" 
                                   class="form-control bg-dark text-white border-0 shadow-sm" 
                                   id="student_no" 
                                   name="student_no" 
                                   placeholder="Enter student number"
                                   style="border-left: 3px solid #0575e6 !important;"
                                   required>
                        </div>
                    </div>

                    <!-- Full Name -->
                    <div class="mb-4">
                        <label for="fullname" class="form-label text-white-50 fw-semibold mb-2">
                            <i class="bi bi-person-fill text-info"></i> Full Name
                        </label>
                        <div class="input-group input-group-lg">
                            <span class="input-group-text bg-dark border-0 text-info">
                                <i class="bi bi-pencil-fill"></i>
                            </span>
                            <input type="text" 
                                   class="form-control bg-dark text-white border-0 shadow-sm" 
                                   id="fullname" 
                                   name="fullname" 
                                   placeholder="Enter full name"
                                   style="border-left: 3px solid #0575e6 !important;"
                                   required>
                        </div>
                    </div>

                    <!-- Course and Section Row -->
                    <div class="row g-3 mb-4">
                        <!-- Course -->
                        <div class="col-md-6">
                            <label for="course" class="form-label text-white-50 fw-semibold mb-2">
                                <i class="bi bi-book-fill text-info"></i> Course
                            </label>
                            <div class="input-group input-group-lg">
                                <span class="input-group-text bg-dark border-0 text-info">
                                    <i class="bi bi-mortarboard-fill"></i>
                                </span>
                                <select class="form-select bg-dark text-white border-0 shadow-sm" 
                                        id="course" 
                                        name="course" 
                                        style="border-left: 3px solid #0575e6 !important;"
                                        required>
                                    <option value="" selected disabled>Select Course</option>
                                    <option value="BSIT">BSIT</option>
                                    <option value="BEED">BEED</option>
                                </select>
                            </div>
                        </div>

                        <!-- Section -->
                        <div class="col-md-6">
                            <label for="section" class="form-label text-white-50 fw-semibold mb-2">
                                <i class="bi bi-grid-3x3-gap-fill text-info"></i> Section
                            </label>
                            <div class="input-group input-group-lg">
                                <span class="input-group-text bg-dark border-0 text-info">
                                    <i class="bi bi-collection-fill"></i>
                                </span>
                                <select class="form-select bg-dark text-white border-0 shadow-sm" 
                                        id="section" 
                                        name="section" 
                                         style="border-left: 3px solid #0575e6 !important;"
                                        required>
                                    <option value="" selected disabled>Select Section</option>
                                    <?php
                                    if ($result && mysqli_num_rows($result) > 0) {
                                        while ($row = mysqli_fetch_assoc($result)) {
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
                        <button type="submit" class="btn btn-lg fw-bold text-white py-3 rounded-3 shadow-lg btn-save-student">
                            <i class="bi bi-check-circle-fill me-2"></i> Save Student
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>