/**
 * Attendance list modal (Present / Absent).
 *
 * Opened from the two split tiles on a dashboard subject card. The list
 * itself is rendered by components/view_attendance.php and injected
 * whole; this file owns the header, the loading and error panels, and
 * the client-side filter.
 *
 * Styling: assets/css/modal-form.css (.app-modal + the DATA MODAL
 * section) — the same as view_absences_modal.php beside it.
 */

(function () {
    'use strict';

    function el(id) {
        return document.getElementById(id);
    }

    function formatDate(date) {
        try {
            // The time avoids the string being read as UTC and landing on
            // the day before.
            return new Date(date + 'T00:00:00').toLocaleDateString('en-US', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        } catch (e) {
            return date;
        }
    }

    // ─── Entry point (called from the dashboard tiles) ───────────
    window.viewAttendance = function (subject, section, status, date) {
        var present = status !== 'absent';

        bootstrap.Modal.getOrCreateInstance(el('attendanceModal')).show();

        // The tile carries the status colour. It used to be an icon
        // concatenated onto the front of the title, which also meant the
        // subject and section went into innerHTML unescaped — a subject
        // with an "&" or a "<" in it broke the header. Both are
        // textContent now, so neither can.
        var icon = el('attendanceModalIcon');
        icon.className = 'app-modal-icon ' + (present ? 'is-ok' : 'is-bad');
        icon.innerHTML = '<i class="bi bi-' + (present ? 'check2-circle' : 'x-circle') + '"></i>';

        el('attendanceModalLabel').textContent = present ? 'Present students' : 'Absent students';
        el('attendanceModalDate').textContent =
            subject + ' · Section ' + section + ' · ' + formatDate(date);

        el('attendanceModalBody').innerHTML =
            '<div class="app-state">' +
            '<div class="spinner-border" role="status"><span class="visually-hidden">Loading...</span></div>' +
            '<h6>Loading the list</h6>' +
            '<p>Fetching who was recorded for this session.</p>' +
            '</div>';

        var query = new URLSearchParams({
            subject: subject,
            section: section,
            status: present ? 'present' : 'absent',
            date: date,
            _t: Date.now()          // cache buster
        });

        fetch('../components/view_attendance.php?' + query.toString(), {
            method: 'GET',
            cache: 'no-store',
            headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' }
        })
            .then(function (response) {
                if (!response.ok) throw new Error('Network response was not ok');
                return response.text();
            })
            .then(function (html) {
                el('attendanceModalBody').innerHTML = html;
            })
            .catch(function (error) {
                el('attendanceModalBody').innerHTML =
                    '<div class="app-state">' +
                    '<div class="app-state-icon is-bad"><i class="bi bi-exclamation-octagon"></i></div>' +
                    '<h6>Could not load the list</h6>' +
                    '<p></p>' +
                    '</div>';
                // textContent, so a server message cannot inject markup.
                el('attendanceModalBody').querySelector('.app-state p').textContent =
                    error.message || 'Please try again.';
            });
    };

    // ─── Filter ──────────────────────────────────────────────────
    // Delegated, because the input arrives with the fetched fragment and
    // is replaced on every open — a listener bound to the element itself
    // would have to be rebound each time, and the one that forgets is
    // the bug.
    document.addEventListener('input', function (e) {
        if (!e.target || e.target.id !== 'attFilter') return;

        var query = e.target.value.trim().toLowerCase();
        var rows = document.querySelectorAll('#attendanceModalBody tbody tr');
        var shown = 0;

        rows.forEach(function (row) {
            var hit = query === '' || (row.getAttribute('data-find') || '').indexOf(query) !== -1;
            row.style.display = hit ? '' : 'none';

            // Renumbered as it filters. Left alone, the # column keeps the
            // gaps of the rows it is hiding, which reads as a list with
            // people missing from it.
            if (hit) {
                shown++;
                row.cells[0].textContent = shown;
            }
        });

        var wrap = el('attTableWrap');
        var none = el('attNoMatch');
        if (wrap) wrap.style.display = shown === 0 ? 'none' : '';
        if (none) none.style.display = shown === 0 ? 'flex' : 'none';

        var count = el('attShown');
        if (count) {
            count.textContent = query === ''
                ? ''
                : 'Showing ' + shown + ' of ' + rows.length;
        }
    });
})();
