<!-- View Absences Modal -->
<div class="modal fade" id="viewAbsencesModal" tabindex="-1" aria-labelledby="viewAbsencesModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content bg-dark text-white">
            <div class="modal-header border-secondary">
                <h5 class="modal-title" id="viewAbsencesModalLabel">
                    <i class="bi bi-exclamation-triangle-fill text-danger me-2"></i>
                    <span id="absencesModalTitle">Students with Absences</span>
                </h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <!-- Loading State -->
                <div id="absencesLoadingState" class="text-center py-5">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p class="mt-3 text-white-50">Loading absences data...</p>
                </div>

                <!-- Content -->
                <div id="absencesContent" style="display: none;">
                    <!-- Info Box -->
                    <div class="alert alert-info border-0 rounded-3 mb-3">
                        <div class="d-flex align-items-start">
                            <i class="bi bi-info-circle-fill me-2 fs-5"></i>
                            <div>
                                <strong id="absencesInfoTitle">Students with 3+ Absences</strong>
                                <p class="mb-0 small mt-1" id="absencesInfoDesc">
                                    Showing students in <strong id="sectionName"></strong> who have missed <strong id="absenceCount"></strong> or more classes
                                </p>
                            </div>
                        </div>
                    </div>

                    <!-- Students Table -->
                    <div class="table-responsive">
                        <table class="table table-dark table-hover">
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>Student No.</th>
                                    <th>Name</th>
                                    <th>Course</th>
                                    <th class="text-center">Total Classes</th>
                                    <th class="text-center">Attended</th>
                                    <th class="text-center">Absences</th>
                                </tr>
                            </thead>
                            <tbody id="absencesTableBody">
                                <!-- Data will be loaded here via AJAX -->
                            </tbody>
                        </table>
                    </div>

                    <!-- Empty State -->
                    <div id="absencesEmptyState" class="text-center py-5" style="display: none;">
                        <i class="bi bi-check-circle text-success" style="font-size: 3rem;"></i>
                        <h5 class="mt-3 text-white">Great News!</h5>
                        <p class="text-white-50">No students have reached this absence threshold</p>
                    </div>
                </div>

                <!-- Error State -->
                <div id="absencesErrorState" class="text-center py-5" style="display: none;">
                    <i class="bi bi-exclamation-circle text-danger" style="font-size: 3rem;"></i>
                    <h5 class="mt-3 text-white">Error Loading Data</h5>
                    <p class="text-white-50" id="absencesErrorMessage">Unable to load absences data. Please try again.</p>
                </div>
            </div>
            <div class="modal-footer border-secondary">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                    <i class="bi bi-x-circle me-1"></i> Close
                </button>
                <form id="exportAbsencesPdfForm" action="../exports/export_absences_pdf.php" method="POST" style="display: inline;">
                    <input type="hidden" name="section" id="exportSection">
                    <input type="hidden" name="min_absences" id="exportMinAbsences">
                    <button type="submit" class="btn btn-danger" id="exportAbsencesBtn">
                        <i class="bi bi-file-earmark-pdf me-1"></i> Export to PDF
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>