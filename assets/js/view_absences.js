/**
 * View Absences Modal Handler
 *
 * Shows students at or above an absence threshold, counted by SESSION
 * (one subject on one day) rather than by date — see
 * includes/absences.php. Each row also lists WHICH subjects were
 * missed, which is the question the old modal could not answer.
 *
 * Styling: assets/css/modal-form.css (.app-modal + the DATA MODAL section).
 */

(function () {
    'use strict';

    // What the modal is currently showing. The subject dropdown reloads
    // against these without needing them passed around again.
    let current = { section: '', minAbsences: 3 };

    function el(id) {
        return document.getElementById('viewAbsencesModal').querySelector('#' + id);
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text == null ? '' : text;
        return div.innerHTML;
    }

    // ─── Entry point (called from the dashboard cards) ───────────
    window.viewAbsences = function (section, minAbsences) {
        current = { section: section, minAbsences: Number(minAbsences) || 0 };

        const modal = document.getElementById('viewAbsencesModal');
        const isCritical = current.minAbsences >= 5;

        el('absencesModalTitle').textContent = `Students with ${current.minAbsences}+ Absences`;
        el('absencesModalIcon').className =
            'app-modal-icon ' + (isCritical ? 'is-crit' : 'is-warn');

        el('exportSection').value = section;
        el('exportMinAbsences').value = current.minAbsences;

        // A fresh section means a fresh subject list.
        const select = el('absencesSubject');
        select.innerHTML = '<option value="">All subjects</option>';
        el('absencesFilterWrap').style.display = 'none';

        bootstrap.Modal.getOrCreateInstance(modal).show();
        load(true);
    };

    // ─── Subject filter ──────────────────────────────────────────
    document.addEventListener('change', function (e) {
        if (e.target && e.target.id === 'absencesSubject') {
            load(false);
        }
    });

    /**
     * @param {boolean} rebuildSubjects  Only on a fresh open. Once a
     *   subject is picked the server answers about that subject alone,
     *   so rebuilding the list from that response would leave the
     *   dropdown holding a single option.
     */
    function load(rebuildSubjects) {
        const loading = el('absencesLoadingState');
        const content = el('absencesContent');
        const empty = el('absencesEmptyState');
        const error = el('absencesErrorState');
        const exportForm = el('exportAbsencesPdfForm');
        const subject = el('absencesSubject').value;

        el('exportSubject').value = subject;

        const scope = subject ? subject : `${current.section}`;
        el('absencesModalSubtitle').textContent =
            `${scope} · missed ${current.minAbsences} or more sessions`;
        el('absencesEmptyDesc').textContent = subject
            ? `No student has missed ${current.minAbsences} or more sessions of ${subject}.`
            : `No student in ${current.section} has missed ${current.minAbsences} or more sessions.`;

        loading.style.display = 'flex';
        content.style.display = 'none';
        empty.style.display = 'none';
        error.style.display = 'none';
        exportForm.style.display = 'none';

        const body = new URLSearchParams({
            section: current.section,
            min_absences: current.minAbsences,
            subject: subject
        });

        fetch('../api/get_absences_data.php', { method: 'POST', body: body })
            .then(r => r.json())
            .then(data => {
                loading.style.display = 'none';

                if (!data.success) {
                    error.style.display = 'flex';
                    el('absencesErrorMessage').textContent = data.message || 'Unable to load data.';
                    return;
                }

                if (rebuildSubjects) buildSubjectFilter(data.subjects || []);

                const students = data.students || [];
                const totalSessions = Number(data.total_sessions) || 0;

                // The export follows whatever is on screen, including
                // an empty result — the PDF then says so rather than
                // silently exporting something else.
                exportForm.style.display = 'block';

                if (students.length === 0) {
                    empty.style.display = 'flex';
                    return;
                }

                el('absencesChips').innerHTML = `
                    <span class="app-chip is-info">
                        <i class="bi bi-people-fill"></i>
                        ${students.length} student${students.length === 1 ? '' : 's'}
                    </span>
                    <span class="app-chip is-info">
                        <i class="bi bi-calendar3"></i>
                        ${totalSessions} session${totalSessions === 1 ? '' : 's'} held
                    </span>
                `;

                const tbody = el('absencesTableBody');
                tbody.innerHTML = '';

                students.forEach((student, index) => {
                    const total = Number(student.total_sessions) || 0;
                    const absences = Number(student.absences) || 0;

                    // With nothing recorded yet the rate is 0 / 0 — this
                    // used to render "NaN%" in the badge.
                    const rate = total > 0 ? Math.round((absences / total) * 100) : null;

                    let level = 'is-warn';
                    if (absences >= 7) level = 'is-severe';
                    else if (absences >= 5) level = 'is-crit';

                    // Which subjects, and how many in each. Only shown
                    // when the report spans more than one subject —
                    // inside a single-subject view it would repeat the
                    // number in the next column.
                    const parts = (student.breakdown || []);
                    const breakdown = (!subject && parts.length)
                        ? `<div class="abs-breakdown">${parts.map(b =>
                              `<span class="abs-subj" title="${escapeHtml(b.subject || 'No subject recorded')}: ${b.attended} of ${b.sessions} attended">
                                   ${escapeHtml(b.subject || 'No subject')} <b>${b.absences}</b>
                               </span>`).join('')}</div>`
                        : '';

                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td class="app-rank">${index + 1}</td>
                        <td class="app-id">${escapeHtml(student.student_no)}</td>
                        <td>${escapeHtml(student.name)}${breakdown}</td>
                        <td class="app-num">${student.attended} / ${total}</td>
                        <td class="app-num">
                            <span class="app-count ${level}">
                                ${absences}${rate === null ? '' : ` <small>${rate}%</small>`}
                            </span>
                        </td>
                    `;
                    tbody.appendChild(row);
                });

                content.style.display = 'block';
            })
            .catch(err => {
                console.error('Error:', err);
                loading.style.display = 'none';
                error.style.display = 'flex';
                el('absencesErrorMessage').textContent = 'Network error. Please try again.';
            });
    }

    function buildSubjectFilter(subjects) {
        const select = el('absencesSubject');
        const wrap = el('absencesFilterWrap');

        select.innerHTML = '<option value="">All subjects</option>';

        subjects.forEach(s => {
            const opt = document.createElement('option');
            opt.value = s.subject;
            opt.textContent = (s.subject || 'No subject recorded') +
                ` (${s.sessions} session${s.sessions === 1 ? '' : 's'})`;
            select.appendChild(opt);
        });

        // With one subject there is nothing to filter — the dropdown
        // would only be a control that cannot change anything.
        wrap.style.display = subjects.length > 1 ? 'block' : 'none';
    }
})();
