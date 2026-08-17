<!-- Attendance list modal (Present / Absent)

     Styling lives in assets/css/modal-form.css (.app-modal plus the
     DATA MODAL section) — the same vocabulary as
     view_absences_modal.php, which opens from the card right beside
     this one. It used to carry its own: a hardcoded
     `linear-gradient(#1e1e2e, #2d2d44)` background and `text-white` on
     every element, so in light mode it opened as a dark box in the
     middle of a light page, and none of it followed theme.css.

     The ids must not change — assets/js/view_attendance.js reads them,
     and components/view_attendance.php is injected into
     #attendanceModalBody. -->
<div class="modal fade app-modal" id="attendanceModal" tabindex="-1" aria-labelledby="attendanceModalLabel" aria-hidden="true">
    <!-- Deliberately NOT `modal-dialog-scrollable`. The table scrolls
         inside .app-table-wrap (that is what keeps its head sticky), so
         a scrollable body put a SECOND scrollbar right beside the first
         one — and it scrolled the chips and the filter box off the top,
         which is the one control that must stay reachable while you
         read the list. -->
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">

            <div class="modal-header">
                <!-- The status colour lives on the tile, so the title
                     does not have to carry an icon glued to the front of
                     its text. -->
                <div class="app-modal-icon" id="attendanceModalIcon"><i class="bi bi-people-fill"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="attendanceModalLabel">Attendance</h5>
                    <!-- Subject, section and date are written here, once.
                         They used to be in the title AND repeated across
                         three full-size summary tiles below it. -->
                    <p id="attendanceModalDate"></p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <!-- Replaced wholesale by the fetched fragment. `aria-live`
                 is what tells a screen reader the list arrived, since
                 nothing here moves focus. -->
            <div class="modal-body" id="attendanceModalBody" aria-live="polite">
                <div class="app-state">
                    <div class="spinner-border" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <h6>Loading the list</h6>
                </div>
            </div>

            <div class="modal-footer">
                <button type="button" class="app-btn ghost" data-bs-dismiss="modal">
                    <i class="bi bi-x-lg" aria-hidden="true"></i> Close
                </button>
            </div>

        </div>
    </div>
</div>
