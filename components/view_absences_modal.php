<!-- View Absences Modal
     Ang anyo ay nasa assets/css/modal-form.css (klase: .app-modal at
     ang seksyong DATA MODAL). Ang mga id ay hindi dapat baguhin —
     sila ang binabasa ng assets/js/view_absences.js at ang mga
     hidden field ay ang inaasahan ng exports/export_absences_pdf.php. -->
<div class="modal fade app-modal" id="viewAbsencesModal" tabindex="-1" aria-labelledby="viewAbsencesModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon" id="absencesModalIcon"><i class="bi bi-exclamation-triangle-fill"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="viewAbsencesModalLabel">
                        <span id="absencesModalTitle">Students with Absences</span>
                    </h5>
                    <!-- Dati ay inuulit ng isang `alert-info` na kahon sa ibaba
                         ang buong pamagat at saka ang seksyon; dito na lang
                         nakasulat ang konteksto — isang beses. -->
                    <p id="absencesModalSubtitle"></p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">

                <!-- Naglo-load -->
                <div id="absencesLoadingState" class="app-state">
                    <div class="spinner-border" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <h6>Checking attendance</h6>
                    <p>Counting missed class days for this section.</p>
                </div>

                <!-- Listahan -->
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
                                <!-- Ilalagay dito ng view_absences.js -->
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Walang tumugma -->
                <div id="absencesEmptyState" class="app-state" style="display: none;">
                    <div class="app-state-icon"><i class="bi bi-clipboard-check"></i></div>
                    <h6>No students at this threshold</h6>
                    <p id="absencesEmptyDesc">Nobody in this section has missed that many classes yet.</p>
                </div>

                <!-- Mali -->
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
                <!-- Itinatago kapag walang ie-export; ang naka-disable na
                     butones ay isang patay na dulo lang. -->
                <form id="exportAbsencesPdfForm" action="../exports/export_absences_pdf.php" method="POST">
                    <input type="hidden" name="section" id="exportSection">
                    <input type="hidden" name="min_absences" id="exportMinAbsences">
                    <!-- Ang tanging punong aksyon. Pula ito dati — nakalaan ang
                         pula sa mapanira, at hindi mapanira ang mag-export. -->
                    <button type="submit" class="app-btn primary" id="exportAbsencesBtn">
                        <i class="bi bi-file-earmark-arrow-down" aria-hidden="true"></i> Export to PDF
                    </button>
                </form>
            </div>

        </div>
    </div>
</div>
