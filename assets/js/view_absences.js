/**
 * View Absences Modal Handler
 * Displays students with specified number of absences
 *
 * Styling: assets/css/modal-form.css (.app-modal + the DATA MODAL section).
 */

function viewAbsences(section, minAbsences) {
    // Every lookup is scoped to the modal. The old code used
    // `document.querySelector('.table-responsive')` — that is global,
    // and view_attendance and userManagementModal have a box like that
    // on the same page, so it hid the FIRST one it found, which was
    // not always this modal's.
    const modal = document.getElementById('viewAbsencesModal');
    const $ = (id) => modal.querySelector('#' + id);

    const loading = $('absencesLoadingState');
    const content = $('absencesContent');
    const empty = $('absencesEmptyState');
    const error = $('absencesErrorState');
    const exportForm = $('exportAbsencesPdfForm');

    const isCritical = minAbsences >= 5;

    // ─── Header ─────────────────────────────────────────────
    $('absencesModalTitle').textContent = `Students with ${minAbsences}+ Absences`;
    $('absencesModalSubtitle').textContent =
        `${section} · missed ${minAbsences} or more class days`;

    // Follows the color of the dashboard card that was clicked
    // (.dash-risk.warn for 3+, .crit for 5+).
    $('absencesModalIcon').className = 'app-modal-icon ' + (isCritical ? 'is-crit' : 'is-warn');

    $('absencesEmptyDesc').textContent =
        `No student in ${section} has missed ${minAbsences} or more classes.`;

    // ─── Export form ────────────────────────────────────────
    $('exportSection').value = section;
    $('exportMinAbsences').value = minAbsences;

    // ─── Initial state ──────────────────────────────────────
    loading.style.display = 'flex';
    content.style.display = 'none';
    empty.style.display = 'none';
    error.style.display = 'none';
    exportForm.style.display = 'none';

    // `getOrCreateInstance` rather than `new` — reuses the instance on
    // every open instead of leaving a new one behind on each click of
    // the section cards.
    bootstrap.Modal.getOrCreateInstance(modal).show();

    fetch('../api/get_absences_data.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `section=${encodeURIComponent(section)}&min_absences=${minAbsences}`
    })
        .then(response => response.json())
        .then(data => {
            loading.style.display = 'none';

            if (!data.success) {
                error.style.display = 'flex';
                $('absencesErrorMessage').textContent = data.message || 'Unable to load data.';
                return;
            }

            const students = data.students || [];

            if (students.length === 0) {
                empty.style.display = 'flex';
                return;
            }

            // ─── Summary ────────────────────────────────────
            const totalClasses = Number(data.total_classes) || 0;
            $('absencesChips').innerHTML = `
                <span class="app-chip is-info">
                    <i class="bi bi-people-fill"></i>
                    ${students.length} student${students.length === 1 ? '' : 's'}
                </span>
                <span class="app-chip is-info">
                    <i class="bi bi-calendar3"></i>
                    ${totalClasses} class day${totalClasses === 1 ? '' : 's'} held
                </span>
            `;

            // ─── Rows ───────────────────────────────────────
            const tbody = $('absencesTableBody');
            tbody.innerHTML = '';

            students.forEach((student, index) => {
                const total = Number(student.total_classes) || 0;
                const absences = Number(student.absences) || 0;

                // With no classes recorded yet the rate is `0 / 0` —
                // a new section used to show "NaN%" in the badge.
                const rate = total > 0 ? Math.round((absences / total) * 100) : null;

                // The old three tiers never reached the heaviest one:
                // `>= 5` was tested before `>= 7`, so the last branch
                // was dead — and it was `bg-dark`, nearly invisible on
                // a dark table.
                let level = 'is-warn';
                if (absences >= 7) {
                    level = 'is-severe';
                } else if (absences >= 5) {
                    level = 'is-crit';
                }

                const row = document.createElement('tr');
                row.innerHTML = `
                    <td class="app-rank">${index + 1}</td>
                    <td class="app-id">${escapeHtml(student.student_no)}</td>
                    <td>${escapeHtml(student.name)}</td>
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
            exportForm.style.display = 'block';
        })
        .catch(err => {
            console.error('Error:', err);
            loading.style.display = 'none';
            error.style.display = 'flex';
            $('absencesErrorMessage').textContent = 'Network error. Please try again.';
        });
}

// Helper function to escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
