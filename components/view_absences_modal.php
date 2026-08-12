<!-- View Absences Modal
     Styling lives in assets/css/modal-form.css (class: .app-modal plus
     the DATA MODAL section). The ids must not change — they are what
     assets/js/view_absences.js reads, and the hidden fields are what
     exports/export_absences_pdf.php expects. -->
<div class="modal fade app-modal" id="viewAbsencesModal" tabindex="-1" aria-labelledby="viewAbsencesModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon" id="absencesModalIcon"><i class="bi bi-exclamation-triangle-fill"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="viewAbsencesModalLabel">
                        <span id="absencesModalTitle">Students with Absences</span>
                    </h5>
                    <!-- An `alert-info` box below used to repeat the whole
                         title and then the section; the context is written
                         here instead — once. -->
                    <p id="absencesModalSubtitle"></p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">

                <!-- Loading -->
                <div id="absencesLoadingState" class="app-state">
                    <div class="spinner-border" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <h6>Checking attendance</h6>
                    <p>Counting missed class days for this section.</p>
                </div>

                <!-- The list -->
                <div id="absencesContent" style="display: none;">
                    <div class="app-chips" id="absencesChips"></div>

                    <div class="app-table-wrap" id="absencesTableWrap">
                        <table class="app-table">
                            <thead>
                                <tr>
                                    <th class="app-rank">#</th>
                                    <th>Student No.</th>
                                    <th>Name</th>
                                    <th class="app-num">Present</th>
                                    <th class="app-num">Absences</th>
                                </tr>
                            </thead>
                            <tbody id="absencesTableBody">
                                <!-- Filled in by view_absences.js -->
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- No matches -->
                <div id="absencesEmptyState" class="app-state" style="display: none;">
                    <div class="app-state-icon"><i class="bi bi-clipboard-check"></i></div>
                    <h6>No students at this threshold</h6>
                    <p id="absencesEmptyDesc">Nobody in this section has missed that many classes yet.</p>
                </div>

                <!-- Error -->
                <div id="absencesErrorState" class="app-state" style="display: none;">
                    <div class="app-state-icon is-bad"><i class="bi bi-exclamation-octagon"></i></div>
                    <h6>Could not load the list</h6>
                    <p id="absencesErrorMessage">Unable to load absences data. Please try again.</p>
                </div>

            </div>

            <div class="modal-footer">
                <button type="button" class="app-btn ghost" data-bs-dismiss="modal">
                    <i class="bi bi-x-lg" aria-hidden="true"></i> Close
                </button>
                <!-- Hidden when there is nothing to export; a disabled
                     button is just a dead end. -->
                <form id="exportAbsencesPdfForm" action="../exports/export_absences_pdf.php" method="POST">
                    <input type="hidden" name="section" id="exportSection">
                    <input type="hidden" name="min_absences" id="exportMinAbsences">
                    <!-- The only primary action. It was red before — red is
                         reserved for destructive actions, and exporting is
                         not one. -->
                    <button type="submit" class="app-btn primary" id="exportAbsencesBtn">
                        <i class="bi bi-file-earmark-arrow-down" aria-hidden="true"></i> Export to PDF
                    </button>
                </form>
            </div>

        </div>
    </div>
</div>
