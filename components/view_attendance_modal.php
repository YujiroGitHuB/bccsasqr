<!-- view Attendance Modal -->
<div class="modal fade" id="attendanceModal" tabindex="-1" aria-labelledby="attendanceModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-scrollable modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg" style="background: linear-gradient(135deg, #1e1e2e 0%, #2d2d44 100%);">
            <div class="modal-header border-0 pb-0">
                <div>
                    <h5 class="modal-title text-white fw-bold mb-1" id="attendanceModalLabel">
                        <i class="bi bi-people-fill"></i> Attendance Details
                    </h5>
                    <small class="text-white-50" id="attendanceModalDate"></small>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body pt-2" id="attendanceModalBody">
                <div class="text-center py-5">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p class="text-white-50 mt-3">Loading attendance data...</p>
                </div>
            </div>
            <div class="modal-footer border-0 pt-0">
                <button type="button" class="btn btn-outline-light rounded-pill px-4" data-bs-dismiss="modal">
                    <i class="bi bi-x-circle"></i> Close
                </button>
            </div>
        </div>
    </div>
</div>