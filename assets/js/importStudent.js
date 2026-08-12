// ============================================================
// Student import from CSV/XLS
//
// The dialogs' styling lives in assets/css/modal-form.css (class:
// .app-swal) — the same as .app-modal, so the whole Students page
// flow has one face.
// ============================================================

// The file name and the error messages go into SweetAlert's `html:`,
// which is innerHTML. Both come from outside: the user picks the file
// name, and the errors contain student numbers taken straight out of
// the uploaded spreadsheet (see crud/import_students.php:51). Without
// escaping, a cell containing markup would run in the admin's
// browser.
function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, c => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
    })[c]);
}

// Shared by every dialog in this flow.
const SWAL_APP = {
    background: '#16161a',
    color: '#f1f5f9',
    customClass: { popup: 'app-swal' },
    buttonsStyling: false,
    showClass: { popup: 'swal2-noanimation' }
};

function swalHead(icon, title, subtitle, tone) {
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
    const importBtn = document.getElementById('importCsvBtn');
    const csvFileInput = document.getElementById('csvFileInput');

    // ✅ Accept both .csv and .xls
    csvFileInput.setAttribute('accept', '.csv,.xls');

    if (importBtn) {
        importBtn.addEventListener('click', function () {
            csvFileInput.click();
        });
    }

    if (csvFileInput) {
        csvFileInput.addEventListener('change', function (e) {
            const file = e.target.files[0];
            if (!file) return;

            const isCSV = file.name.toLowerCase().endsWith('.csv');
            const isXLS = file.name.toLowerCase().endsWith('.xls');

            if (!isCSV && !isXLS) {
                Swal.fire({
                    ...SWAL_APP,
                    html: swalHead('bi-file-earmark-x-fill', 'Invalid File', 'That file type cannot be imported.', 'bad') + `
                        <div class="app-swal-body">
                            <div class="app-note is-warn">
                                <i class="bi bi-exclamation-triangle-fill"></i>
                                <span>Please select a <code>.csv</code> or <code>.xls</code> file only.</span>
                            </div>
                        </div>`,
                    confirmButtonText: 'OK'
                });
                csvFileInput.value = '';
                return;
            }

            // ✅ Try to parse course & section from filename
            // Expected format: SubjectName-COURSE_SECTION.xls
            // e.g. Applications_Development-BSIT_2A.xls → course=BSIT, section=2A
            let detectedCourse = '';
            let detectedSection = '';

            const nameParts = file.name.replace(/\.(csv|xls)$/i, '').split('-');
            if (nameParts.length >= 2) {
                const lastPart = nameParts[nameParts.length - 1]; // e.g. BSIT_2A
                const courseSec = lastPart.split('_');
                if (courseSec.length >= 2) {
                    detectedCourse = courseSec[0].trim();                        // BSIT
                    detectedSection = courseSec.slice(1).join('_').trim();        // 2A or 3A-1
                }
            }

            const note = isXLS
                ? `<div class="app-note is-info">
                       <i class="bi bi-info-circle-fill"></i>
                       <span>Course and section were read from the filename. Check them before importing.</span>
                   </div>`
                : `<div class="app-note is-warn">
                       <i class="bi bi-exclamation-triangle-fill"></i>
                       <span>CSV needs these columns: <code>student_no</code>, <code>fullname</code>, <code>course</code>, <code>section</code></span>
                   </div>`;

            const sizeKb = (file.size / 1024).toFixed(2);

            // ✅ Show confirmation with editable course & section fields
            Swal.fire({
                ...SWAL_APP,
                html:
                    swalHead('bi-upload', 'Import Students?', 'Review the details before adding these records.') + `
                    <div class="app-swal-body">
                        <div class="app-swal-file">
                            <i class="bi ${isXLS ? 'bi-file-earmark-spreadsheet' : 'bi-filetype-csv'}"></i>
                            <div class="app-swal-file-meta">
                                <span class="app-swal-file-name" title="${esc(file.name)}">${esc(file.name)}</span>
                                <span class="app-swal-file-size">${sizeKb} KB &middot; ${isXLS ? 'XLS' : 'CSV'}</span>
                            </div>
                        </div>

                        ${note}

                        <div class="row g-3">
                            <div class="col-6">
                                <div class="app-field">
                                    <label class="form-label" for="swal-course">Course</label>
                                    <div class="app-input">
                                        <i class="bi bi-mortarboard-fill"></i>
                                        <input id="swal-course" class="form-control"
                                               placeholder="e.g. BSIT" value="${esc(detectedCourse)}">
                                    </div>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="app-field">
                                    <label class="form-label" for="swal-section">Section</label>
                                    <div class="app-input">
                                        <i class="bi bi-grid-3x3-gap-fill"></i>
                                        <input id="swal-section" class="form-control"
                                               placeholder="e.g. 2A" value="${esc(detectedSection)}">
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>`,
                showCancelButton: true,
                confirmButtonText: 'Import',
                cancelButtonText: 'Cancel',
                showLoaderOnConfirm: true,
                preConfirm: () => {
                    const course = document.getElementById('swal-course').value.trim();
                    const section = document.getElementById('swal-section').value.trim();

                    if (isXLS && (!course || !section)) {
                        Swal.showValidationMessage('Course and Section are required for XLS import.');
                        return false;
                    }

                    return uploadFile(file, course, section, isXLS ? 'xls' : 'csv');
                },
                allowOutsideClick: () => !Swal.isLoading()
            }).then(() => {
                csvFileInput.value = '';
            });
        });
    }
});

function uploadFile(file, course, section, fileType) {
    const formData = new FormData();
    formData.append('csv_file', file);
    formData.append('course', course);
    formData.append('section', section);
    formData.append('file_type', fileType);

    return fetch('../crud/import_students.php', {
        method: 'POST',
        body: formData
    })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                let errorHtml = '';
                if (data.errors && data.errors.length > 0) {
                    // Collapsed by default — the counts are what needs to
                    // be seen first, not the long list.
                    errorHtml = `
                        <details class="app-errors">
                            <summary>${data.errors.length} row${data.errors.length === 1 ? '' : 's'} need attention</summary>
                            <ul>${data.errors.map(err => `<li>${esc(err)}</li>`).join('')}</ul>
                        </details>`;
                }

                Swal.fire({
                    ...SWAL_APP,
                    html:
                        swalHead('bi-check-lg', 'Import Successful', 'The student list has been updated.', 'ok') + `
                        <div class="app-swal-body">
                            <p style="margin:0">${esc(data.message)}</p>
                            <div class="app-chips">
                                <span class="app-chip is-ok"><i class="bi bi-check-circle-fill"></i> ${Number(data.imported) || 0} imported</span>
                                <span class="app-chip is-warn"><i class="bi bi-slash-circle"></i> ${Number(data.skipped) || 0} skipped</span>
                            </div>
                            ${errorHtml}
                        </div>`,
                    confirmButtonText: 'Done'
                }).then(() => location.reload());
            } else {
                throw new Error(data.message || 'Import failed');
            }
        })
        .catch(error => {
            Swal.fire({
                ...SWAL_APP,
                html:
                    swalHead('bi-exclamation-triangle-fill', 'Import Failed', 'No records were added.', 'bad') + `
                    <div class="app-swal-body">
                        <p style="margin:0">${esc(error.message || 'An error occurred while importing the file.')}</p>
                    </div>`,
                confirmButtonText: 'Close'
            });
        });
}
