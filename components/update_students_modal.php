<?php
// Fetch unique sections from database for edit modal
$query_edit = "SELECT DISTINCT section FROM students_tbl WHERE section IS NOT NULL AND section != '' ORDER BY section ASC";
$result_edit = mysqli_query($conn, $query_edit);
?>

<!-- Edit Student Modal
     Ang anyo ay nasa assets/css/modal-form.css (klase: .app-modal) —
     pareho ng Add Student. Ang mga id at `name` ay hindi dapat
     baguhin: sila ang binabasa ng assets/js/editStudent.js at ng
     crud/update_students.php.

     Berde ang buong modal na ito dati (#10a824 → #0b5e15 sa badge,
     #28a745 sa mga gilid ng patlang). Ang berde ay nakalaan sa
     ESTADO sa buong app — Active, Present — kaya nakikipag-agawan
     ito sa mga tunay na badge sa talahanayan sa likod. Ang icon at
     ang pamagat ang nagsasabing "pag-edit ito", hindi ang kulay. -->
<div class="modal fade app-modal" id="editModal" tabindex="-1" aria-labelledby="editModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon"><i class="bi bi-pencil-square"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="editModalLabel">Edit Student</h5>
                    <p>Changes here take effect the next time this student is scanned.</p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">
                <form id="updateStudentForm" class="needs-validation" novalidate>
                    <input type="hidden" name="id" id="edit_id">

                    <!-- Student Number -->
                    <div class="app-field">
                        <label for="edit_student_no" class="form-label">Student Number</label>
                        <div class="app-input">
                            <i class="bi bi-person-badge" aria-hidden="true"></i>
                            <input type="text"
                                class="form-control"
                                id="edit_student_no"
                                name="student_no"
                                placeholder="019-464"
                                autocomplete="off"
                                aria-describedby="edit_student_no_hint"
                                required>
                        </div>
                        <!-- Ang pormat ay itinutugma sa sinusuri ng QR generator
                             (`\d{3}-\d{3,4}` sa QRgenerator/js/fetch_students.js) —
                             kung masira ito rito, hindi na makakagawa ng QR ang
                             estudyante. -->
                        <span class="app-hint" id="edit_student_no_hint">Format: YEAR-Registration No. — e.g. 019-464 or 025-1023</span>
                    </div>

                    <!-- Full Name -->
                    <div class="app-field">
                        <label for="edit_fullname" class="form-label">Full Name</label>
                        <div class="app-input">
                            <i class="bi bi-person-fill" aria-hidden="true"></i>
                            <input type="text"
                                class="form-control"
                                id="edit_fullname"
                                name="fullname"
                                placeholder="Cayading, Charles Nixon C."
                                autocomplete="off"
                                aria-describedby="edit_fullname_hint"
                                required>
                        </div>
                        <span class="app-hint" id="edit_fullname_hint">Last name first, as it should appear on the QR.</span>
                    </div>

                    <!-- Course and Section Row -->
                    <div class="row g-3">
                        <div class="col-md-6">
                            <div class="app-field">
                                <label for="edit_course" class="form-label">Course</label>
                                <div class="app-input">
                                    <i class="bi bi-mortarboard-fill" aria-hidden="true"></i>
                                    <select class="form-select" id="edit_course" name="course" required>
                                        <option value="" disabled>Select Course</option>
                                        <option value="BSIT">BSIT</option>
                                        <option value="BEED">BEED</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="app-field">
                                <label for="edit_section" class="form-label">Section</label>
                                <div class="app-input">
                                    <i class="bi bi-grid-3x3-gap-fill" aria-hidden="true"></i>
                                    <select class="form-select" id="edit_section" name="section" required>
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
                    </div>

                    <!-- Nasa loob ng <form> ang paanan para manatiling katutubo
                         ang pagsumite ng Save. -->
                    <div class="app-modal-footer">
                        <button type="button" class="app-btn ghost" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="app-btn primary">
                            <i class="bi bi-check-circle-fill" aria-hidden="true"></i> Save Changes
                        </button>
                    </div>
                </form>
            </div>

        </div>
    </div>
</div>
