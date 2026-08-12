// ============================================================
// Promote Section — moves a whole section up a year level.
//
// The dialogs' styling lives in assets/css/modal-form.css
// (.app-modal, .app-swal), the same as the import flow, so the
// Students page keeps one face.
//
// Everything is wrapped in an IIFE on purpose: assets/js/importStudent.js
// already declares `esc`, `SWAL_APP`, and `swalHead` at the top level
// of a classic script. Re-declaring any of them here would throw and
// take this whole file down with it.
// ============================================================

(function () {
    'use strict';

    // The counts and section names come back from the server and go
    // into SweetAlert's `html:`, which is innerHTML. Section names are
    // typed by the admin, so they get escaped like any other input.
    function esc(value) {
        return String(value ?? '').replace(/[&<>"']/g, c => ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        })[c]);
    }

    const SWAL = {
        background: '#16161a',
        color: '#f1f5f9',
        customClass: { popup: 'app-swal' },
        buttonsStyling: false,
        showClass: { popup: 'swal2-noanimation' }
    };

    function head(icon, title, subtitle, tone) {
        return `
            <div class="app-swal-head ${tone ? 'is-' + tone : ''}">
                <div class="app-modal-icon"><i class="bi ${icon}"></i></div>
                <div>
                    <h2>${esc(title)}</h2>
                    <p>${esc(subtitle)}</p>
                </div>
            </div>`;
    }

    document.addEventListener('DOMContentLoaded', function () {
        const form        = document.getElementById('promoteSectionForm');
        if (!form) return;

        const courseSel   = document.getElementById('promote_course');
        const fromSel     = document.getElementById('promote_from');
        const toInput     = document.getElementById('promote_to');
        const moveInstr   = document.getElementById('promote_move_instructors');
        const preview     = document.getElementById('promotePreview');
        const chips       = document.getElementById('promoteChips');
        const mergeBox    = document.getElementById('promoteMergeWarning');
        const submitBtn   = document.getElementById('promoteSubmitBtn');
        const modalEl     = document.getElementById('promoteSectionModal');

        // The full option list is captured once. Filtering by hiding
        // options is unreliable — Safari and older Edge ignore
        // `hidden` on <option> — so the list is rebuilt instead.
        const allOptions = Array.from(fromSel.options)
            .filter(o => o.value !== '')
            .map(o => ({
                value: o.value,
                label: o.textContent.trim(),
                course: o.dataset.course,
                count: Number(o.dataset.count) || 0
            }));

        // ─── Course → rebuild the "From" list ──────────────────────
        courseSel.addEventListener('change', function () {
            const course = courseSel.value;

            fromSel.innerHTML = '<option value="" selected disabled>Select Section</option>';
            allOptions
                .filter(o => o.course === course)
                .forEach(o => {
                    const opt = document.createElement('option');
                    opt.value       = o.value;
                    opt.textContent = o.label;
                    fromSel.appendChild(opt);
                });

            fromSel.disabled = false;
            toInput.value    = '';
            hidePreview();
        });

        // ─── "2A" → "3A" ───────────────────────────────────────────
        // Only the leading number moves. A section named "2A-1" keeps
        // its suffix, and a section with no leading digit (say "IRREG")
        // is left for the admin to type — guessing there would be
        // worse than an empty field.
        function nextSection(section) {
            const m = /^(\d+)(.*)$/.exec(section);
            if (!m) return '';
            return (parseInt(m[1], 10) + 1) + m[2];
        }

        fromSel.addEventListener('change', function () {
            toInput.value = nextSection(fromSel.value);
            refreshPreview();
        });

        // ─── Live preview ──────────────────────────────────────────
        function hidePreview() {
            preview.classList.add('d-none');
            chips.innerHTML    = '';
            mergeBox.innerHTML = '';
        }

        let previewTimer = null;
        let previewSeq   = 0;   // drops responses that arrive out of order

        function refreshPreview() {
            clearTimeout(previewTimer);
            previewTimer = setTimeout(runPreview, 250);
        }

        function runPreview() {
            const course = courseSel.value;
            const from   = fromSel.value;
            const to     = toInput.value.trim();

            if (!course || !from || !to) {
                hidePreview();
                return;
            }

            const seq = ++previewSeq;
            const body = new URLSearchParams({
                mode: 'preview',
                course: course,
                from_section: from,
                to_section: to
            });

            fetch('../crud/promote_section.php', { method: 'POST', body: body })
                .then(r => r.json())
                .then(data => {
                    if (seq !== previewSeq) return;   // a newer keystroke won

                    if (!data.success) {
                        chips.innerHTML = `<span class="app-chip is-warn">
                            <i class="bi bi-exclamation-triangle-fill"></i> ${esc(data.message)}</span>`;
                        mergeBox.innerHTML = '';
                        preview.classList.remove('d-none');
                        return;
                    }

                    chips.innerHTML = `
                        <span class="app-chip is-ok"><i class="bi bi-people-fill"></i>
                            ${data.moving} student${data.moving === 1 ? '' : 's'} move to ${esc(course)}-${esc(to)}</span>
                        <span class="app-chip is-info"><i class="bi bi-person-workspace"></i>
                            ${data.instructors} instructor assignment${data.instructors === 1 ? '' : 's'}</span>`;

                    // The destination already having students is legal —
                    // it is a merge — but it is never what you meant if
                    // you typed the year wrong, so say it out loud.
                    mergeBox.innerHTML = data.destination > 0
                        ? `<div class="app-note is-warn" style="margin:.8rem 0 0">
                               <i class="bi bi-exclamation-triangle-fill"></i>
                               <span><strong>${esc(course)}-${esc(to)}</strong> already has
                               ${data.destination} student${data.destination === 1 ? '' : 's'}.
                               They will be merged into one section.</span>
                           </div>`
                        : '';

                    preview.classList.remove('d-none');
                })
                .catch(() => hidePreview());
        }

        toInput.addEventListener('input', function () {
            toInput.value = toInput.value.toUpperCase();
            refreshPreview();
        });

        // Start clean each time the modal opens — a stale preview from
        // the last promotion would describe a move that already ran.
        if (modalEl) {
            modalEl.addEventListener('show.bs.modal', function () {
                form.reset();
                fromSel.disabled = true;
                fromSel.innerHTML = '<option value="" selected disabled>Select Course first</option>';
                hidePreview();
            });
        }

        // ─── Submit ────────────────────────────────────────────────
        form.addEventListener('submit', function (e) {
            e.preventDefault();

            const course = courseSel.value;
            const from   = fromSel.value;
            const to     = toInput.value.trim();

            if (!course || !from || !to) {
                Swal.fire({
                    ...SWAL,
                    html: head('bi-exclamation-triangle-fill', 'Incomplete', 'Nothing has been changed.', 'bad') +
                        `<div class="app-swal-body"><p style="margin:0">Pick a course, a current section, and a new section.</p></div>`,
                    confirmButtonText: 'OK'
                });
                return;
            }

            if (!/^[A-Za-z0-9-]{1,10}$/.test(to)) {
                Swal.fire({
                    ...SWAL,
                    html: head('bi-exclamation-triangle-fill', 'Invalid Section', 'Nothing has been changed.', 'bad') +
                        `<div class="app-swal-body"><p style="margin:0">The new section may only contain letters, numbers, and dashes (max 10 characters).</p></div>`,
                    confirmButtonText: 'OK'
                });
                return;
            }

            const count = Number(fromSel.selectedOptions[0]?.dataset.count) ||
                          (allOptions.find(o => o.course === course && o.value === from)?.count ?? 0);

            Swal.fire({
                ...SWAL,
                html: head('bi-arrow-up-right-circle-fill', 'Promote Section?',
                           `${esc(course)}-${esc(from)} becomes ${esc(course)}-${esc(to)}.`) + `
                    <div class="app-swal-body">
                        <p style="margin:0 0 .6rem">
                            Every student in <strong>${esc(course)}-${esc(from)}</strong> will be moved to
                            <strong>${esc(course)}-${esc(to)}</strong>.
                        </p>
                        <div class="app-note is-info">
                            <i class="bi bi-info-circle-fill"></i>
                            <span>Past attendance keeps saying <code>${esc(from)}</code> — those records are a
                            snapshot of the date they were taken. Subject enrollments are not touched;
                            set the new term's subjects on the Student Subjects page.</span>
                        </div>
                        <div class="app-chips" style="margin-top:0">
                            <span class="app-chip is-ok"><i class="bi bi-people-fill"></i> ${count} student${count === 1 ? '' : 's'}</span>
                            <span class="app-chip is-info"><i class="bi bi-person-workspace"></i>
                                Instructors: ${moveInstr.checked ? 'moved too' : 'left as-is'}</span>
                        </div>
                    </div>`,
                showCancelButton: true,
                confirmButtonText: 'Promote',
                cancelButtonText: 'Cancel',
                showLoaderOnConfirm: true,
                preConfirm: () => runPromote(course, from, to, moveInstr.checked),
                allowOutsideClick: () => !Swal.isLoading()
            });
        });

        function runPromote(course, from, to, withInstructors) {
            const body = new URLSearchParams({
                mode: 'promote',
                course: course,
                from_section: from,
                to_section: to
            });
            if (withInstructors) body.append('move_instructors', '1');

            return fetch('../crud/promote_section.php', { method: 'POST', body: body })
                .then(r => r.json())
                .then(data => {
                    if (!data.success) throw new Error(data.message || 'Promotion failed');

                    const skipped = Number(data.instructors_skipped) || 0;

                    Swal.fire({
                        ...SWAL,
                        html: head('bi-check-lg', 'Section Promoted', 'The student list has been updated.', 'ok') + `
                            <div class="app-swal-body">
                                <p style="margin:0">${esc(data.message)}</p>
                                <div class="app-chips">
                                    <span class="app-chip is-ok"><i class="bi bi-people-fill"></i>
                                        ${Number(data.students_moved) || 0} student${data.students_moved === 1 ? '' : 's'} moved</span>
                                    <span class="app-chip is-info"><i class="bi bi-person-workspace"></i>
                                        ${Number(data.instructors_moved) || 0} instructor assignment${data.instructors_moved === 1 ? '' : 's'} moved</span>
                                    ${skipped > 0 ? `<span class="app-chip is-warn"><i class="bi bi-slash-circle"></i>
                                        ${skipped} already assigned there</span>` : ''}
                                </div>
                            </div>`,
                        confirmButtonText: 'Done'
                    }).then(() => location.reload());
                })
                .catch(error => {
                    Swal.fire({
                        ...SWAL,
                        html: head('bi-exclamation-triangle-fill', 'Promotion Failed', 'No records were changed.', 'bad') +
                            `<div class="app-swal-body"><p style="margin:0">${esc(error.message)}</p></div>`,
                        confirmButtonText: 'Close'
                    });
                });
        }
    });
})();
