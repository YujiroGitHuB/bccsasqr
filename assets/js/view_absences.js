/**
 * View Absences Modal Handler
 * Displays students with specified number of absences
 *
 * Anyo: assets/css/modal-form.css (.app-modal + seksyong DATA MODAL).
 */

function viewAbsences(section, minAbsences) {
    // Lahat ng hanap ay saklaw ng modal. Ang lumang code ay gumagamit
    // ng `document.querySelector('.table-responsive')` — pandaigdig
    // iyon, at may ganoon ding kahon ang view_attendance at ang
    // userManagementModal sa parehong page, kaya ang UNANG nakita ang
    // itinatago at hindi palaging ang sa modal na ito.
    const modal = document.getElementById('viewAbsencesModal');
    const $ = (id) => modal.querySelector('#' + id);

    const loading = $('absencesLoadingState');
    const content = $('absencesContent');
    const empty = $('absencesEmptyState');
    const error = $('absencesErrorState');
    const exportForm = $('exportAbsencesPdfForm');

    const isCritical = minAbsences >= 5;

    // ─── Ulo ────────────────────────────────────────────────
    $('absencesModalTitle').textContent = `Students with ${minAbsences}+ Absences`;
    $('absencesModalSubtitle').textContent =
        `${section} · missed ${minAbsences} or more class days`;

    // Sinusundan ang kulay ng pinindot na kard sa dashboard
    // (.dash-risk.warn para sa 3+, .crit para sa 5+).
    $('absencesModalIcon').className = 'app-modal-icon ' + (isCritical ? 'is-crit' : 'is-warn');

    $('absencesEmptyDesc').textContent =
        `No student in ${section} has missed ${minAbsences} or more classes.`;

    // ─── Porma ng export ────────────────────────────────────
    $('exportSection').value = section;
    $('exportMinAbsences').value = minAbsences;

    // ─── Simulang kalagayan ─────────────────────────────────
    loading.style.display = 'flex';
    content.style.display = 'none';
    empty.style.display = 'none';
    error.style.display = 'none';
    exportForm.style.display = 'none';

    // `getOrCreateInstance` at hindi `new` — muling ginagamit ang
    // instance sa bawat pagbukas sa halip na mag-iwan ng bago kada
    // pindot sa mga kard ng seksyon.
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

            // ─── Buod ───────────────────────────────────────
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

            // ─── Mga hanay ──────────────────────────────────
            const tbody = $('absencesTableBody');
            tbody.innerHTML = '';

            students.forEach((student, index) => {
                const total = Number(student.total_classes) || 0;
                const absences = Number(student.absences) || 0;

                // Kapag wala pang naitalang klase ay `0 / 0` ang bahagdan —
                // "NaN%" ang lumalabas dati sa badge ng bagong seksyon.
                const rate = total > 0 ? Math.round((absences / total) * 100) : null;

                // Ang lumang tatlong antas ay hindi kailanman umabot sa
                // pinakamabigat: nauuna ang `>= 5` bago ang `>= 7`, kaya
                // patay ang huling sanga — at `bg-dark` pa ito, halos
                // hindi makita sa madilim na talahanayan.
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
