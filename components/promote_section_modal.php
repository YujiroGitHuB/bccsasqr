<?php
// Every course/section pair that currently has students, with its
// headcount. The count rides along in a data-* attribute so the
// "From" dropdown can read "BSIT-2A (130 students)" without a
// second request.
$promote_q = "SELECT course, section, COUNT(*) AS n
              FROM students_tbl
              WHERE course IS NOT NULL AND course != ''
                AND section IS NOT NULL AND section != ''
              GROUP BY course, section
              ORDER BY course ASC, section ASC";
$promote_rows = mysqli_query($conn, $promote_q);

$promote_pairs   = [];
$promote_courses = [];
$promote_all     = [];   // every section name, for the datalist

if ($promote_rows) {
    while ($row = mysqli_fetch_assoc($promote_rows)) {
        $promote_pairs[] = $row;
        $promote_courses[$row['course']] = true;
        $promote_all[$row['section']]    = true;
    }
}
?>

<!-- Promote Section Modal
     Styling lives in assets/css/modal-form.css (class: .app-modal) —
     the same as Add and Edit Student, so the page keeps one face.
     The ids are what assets/js/promoteSection.js reads, and the
     `name`s are what crud/promote_section.php reads. -->
<div class="modal fade app-modal" id="promoteSectionModal" tabindex="-1" aria-labelledby="promoteSectionLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon"><i class="bi bi-arrow-up-right-circle-fill"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="promoteSectionLabel">Promote Section</h5>
                    <p>Moves every student in one section to the next year in a single step.</p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">
                <form id="promoteSectionForm" class="needs-validation" novalidate>

                    <!-- Course -->
                    <div class="app-field">
                        <label for="promote_course" class="form-label">Course</label>
                        <div class="app-input">
                            <i class="bi bi-mortarboard-fill" aria-hidden="true"></i>
                            <select class="form-select" id="promote_course" name="course" required>
                                <option value="" selected disabled>Select Course</option>
                                <?php foreach (array_keys($promote_courses) as $c): ?>
                                    <option value="<?= htmlspecialchars($c) ?>"><?= htmlspecialchars($c) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>

                    <div class="row g-3">
                        <!-- From -->
                        <div class="col-md-6">
                            <div class="app-field">
                                <label for="promote_from" class="form-label">Current Section</label>
                                <div class="app-input">
                                    <i class="bi bi-grid-3x3-gap-fill" aria-hidden="true"></i>
                                    <select class="form-select" id="promote_from" name="from_section" required disabled>
                                        <option value="" selected disabled>Select Course first</option>
                                        <?php foreach ($promote_pairs as $p): ?>
                                            <option value="<?= htmlspecialchars($p['section']) ?>"
                                                    data-course="<?= htmlspecialchars($p['course']) ?>"
                                                    data-count="<?= (int) $p['n'] ?>">
                                                <?= htmlspecialchars($p['section']) ?> — <?= number_format((int) $p['n']) ?> student<?= (int) $p['n'] === 1 ? '' : 's' ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                                <span class="app-hint">Only sections that currently have students.</span>
                            </div>
                        </div>

                        <!-- To -->
                        <div class="col-md-6">
                            <div class="app-field">
                                <label for="promote_to" class="form-label">New Section</label>
                                <div class="app-input">
                                    <i class="bi bi-arrow-right-circle-fill" aria-hidden="true"></i>
                                    <!-- Free text, not a dropdown: next year's
                                         section does not exist in the table yet,
                                         so there would be nothing to pick. The
                                         datalist offers the existing ones for the
                                         case where you are merging into one. -->
                                    <input type="text"
                                        class="form-control"
                                        id="promote_to"
                                        name="to_section"
                                        list="promoteSectionList"
                                        placeholder="3A"
                                        maxlength="10"
                                        autocomplete="off"
                                        pattern="[A-Za-z0-9\-]{1,10}"
                                        aria-describedby="promote_to_hint"
                                        required>
                                </div>
                                <datalist id="promoteSectionList">
                                    <?php foreach (array_keys($promote_all) as $s): ?>
                                        <option value="<?= htmlspecialchars($s) ?>"></option>
                                    <?php endforeach; ?>
                                </datalist>
                                <span class="app-hint" id="promote_to_hint">Filled in for you — edit if the section is named differently.</span>
                            </div>
                        </div>
                    </div>

                    <!-- Live preview. Hidden until there is something real to
                         say; a box reading "0 students" before you have picked
                         anything reads like an error. -->
                    <div id="promotePreview" class="d-none" aria-live="polite">
                        <div class="app-chips" id="promoteChips"></div>
                        <div id="promoteMergeWarning"></div>
                    </div>

                    <!-- Instructor assignments. On by default: leaving it off
                         is what makes an instructor open the dashboard next
                         term and find their section empty. -->
                    <div class="form-check" style="margin-top:1.1rem">
                        <input class="form-check-input" type="checkbox" value="1"
                               id="promote_move_instructors" name="move_instructors" checked>
                        <label class="form-check-label" for="promote_move_instructors" style="font-size:.85rem">
                            Also move instructor assignments for this section
                        </label>
                        <span class="app-hint">Otherwise instructors stay assigned to the old section and lose sight of these students.</span>
                    </div>

                    <div class="app-modal-footer">
                        <button type="button" class="app-btn ghost" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="app-btn primary" id="promoteSubmitBtn">
                            <i class="bi bi-arrow-up-right-circle-fill" aria-hidden="true"></i> Promote
                        </button>
                    </div>
                </form>
            </div>

        </div>
    </div>
</div>
