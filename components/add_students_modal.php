<?php
// Fetch unique sections from database
$query = "SELECT DISTINCT section FROM students_tbl WHERE section IS NOT NULL AND section != '' ORDER BY section ASC";
$result = mysqli_query($conn, $query);
?>

<!-- Add Student Modal
     Styling lives in assets/css/modal-form.css (class: .app-modal).
     The ids and `name`s must not change — they are what
     assets/js/addStudent.js and crud/add_students.php read. -->
<div class="modal fade app-modal" id="addStudentModal" tabindex="-1" aria-labelledby="addStudentLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon"><i class="bi bi-person-plus-fill"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="addStudentLabel">Add New Student</h5>
                    <p>Creates the record every QR scan is checked against.</p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">
                <form id="addStudentForm" class="needs-validation" novalidate>

                    <!-- Student Number -->
                    <div class="app-field">
                        <label for="student_no" class="form-label">Student Number</label>
                        <div class="app-input">
                            <i class="bi bi-person-badge" aria-hidden="true"></i>
                            <input type="text"
                                class="form-control"
                                id="student_no"
                                name="student_no"
                                placeholder="019-464"
                                autocomplete="off"
                                aria-describedby="student_no_hint"
                                required>
                        </div>
                        <!-- The format matches what the QR generator checks
                             (`\d{3}-\d{3,4}` in QRgenerator/js/fetch_students.js) —
                             record it wrong here and the student cannot generate
                             a QR. -->
                        <span class="app-hint" id="student_no_hint">Format: YEAR-Registration No. — e.g. 019-464 or 025-1023</span>
                    </div>

                    <!-- Full Name -->
                    <div class="app-field">
                        <label for="fullname" class="form-label">Full Name</label>
                        <div class="app-input">
                            <i class="bi bi-person-fill" aria-hidden="true"></i>
                            <input type="text"
                                class="form-control"
                                id="fullname"
                                name="fullname"
                                placeholder="Cayading, Charles Nixon C."
                                autocomplete="off"
                                aria-describedby="fullname_hint"
                                required>
                        </div>
                        <span class="app-hint" id="fullname_hint">Last name first, as it should appear on the QR.</span>
                    </div>

                    <!-- Course and Section Row -->
                    <div class="row g-3">
                        <div class="col-md-6">
                            <div class="app-field">
                                <label for="course" class="form-label">Course</label>
                                <div class="app-input">
                                    <i class="bi bi-mortarboard-fill" aria-hidden="true"></i>
                                    <select class="form-select" id="course" name="course" required>
                                        <option value="" selected disabled>Select Course</option>
                                        <option value="BSIT">BSIT</option>
                                        <option value="BEED">BEED</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="app-field">
                                <label for="section" class="form-label">Section</label>
                                <div class="app-input">
                                    <i class="bi bi-grid-3x3-gap-fill" aria-hidden="true"></i>
                                    <select class="form-select" id="section" name="section" required>
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
                    </div>

                    <!-- The footer sits inside the <form> so Save submits
                         natively. -->
                    <div class="app-modal-footer">
                        <button type="button" class="app-btn ghost" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="app-btn primary">
                            <i class="bi bi-check-circle-fill" aria-hidden="true"></i> Save Student
                        </button>
                    </div>
                </form>
            </div>

        </div>
    </div>
</div>
