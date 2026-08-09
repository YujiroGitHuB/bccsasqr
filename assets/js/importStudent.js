document.addEventListener('DOMContentLoaded', function () {
    const importBtn    = document.getElementById('importCsvBtn');
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
                    icon: 'error',
                    title: 'Invalid File',
                    background: '#0f172a',
                    color: '#e0e0e0',
                    text: 'Please select a CSV or XLS file only.'
                });
                csvFileInput.value = '';
                return;
            }

            // ✅ Try to parse course & section from filename
            // Expected format: SubjectName-COURSE_SECTION.xls
            // e.g. Applications_Development-BSIT_2A.xls → course=BSIT, section=2A
            let detectedCourse  = '';
            let detectedSection = '';

            const nameParts = file.name.replace(/\.(csv|xls)$/i, '').split('-');
            if (nameParts.length >= 2) {
                const lastPart   = nameParts[nameParts.length - 1]; // e.g. BSIT_2A
                const courseSec  = lastPart.split('_');
                if (courseSec.length >= 2) {
                    detectedCourse  = courseSec[0].trim();                        // BSIT
                    detectedSection = courseSec.slice(1).join('_').trim();        // 2A or 3A-1
                }
            }

            const hint = isXLS
                ? `<p class="text-info mt-2 small"><i class="bi bi-info-circle"></i> XLS format detected — course &amp; section extracted from filename.</p>`
                : `<p class="text-warning mt-2 small"><i class="bi bi-exclamation-triangle"></i> CSV format — columns needed: <code>student_no, fullname, course, section</code></p>`;

            // ✅ Show confirmation with editable course & section fields
            Swal.fire({
                title: 'Import Students?',
                background: '#0f172a',
                color: '#e0e0e0',
                iconColor: '#4ade80',
                icon: 'question',
                html: `
                    <p><strong>File:</strong> ${file.name}</p>
                    <p><strong>Size:</strong> ${(file.size / 1024).toFixed(2)} KB</p>
                    ${hint}
                    <div class="mt-3 text-start">
                        <label class="form-label small text-muted">Course</label>
                        <input id="swal-course" class="form-control form-control-sm mb-2" 
                            placeholder="e.g. BSIT" value="${detectedCourse}">
                        <label class="form-label small text-muted">Section</label>
                        <input id="swal-section" class="form-control form-control-sm" 
                            placeholder="e.g. 2A" value="${detectedSection}">
                    </div>
                `,
                showCancelButton: true,
                confirmButtonText: 'Yes, Import',
                cancelButtonText: 'Cancel',
                showLoaderOnConfirm: true,
                preConfirm: () => {
                    const course  = document.getElementById('swal-course').value.trim();
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
                    errorHtml = `
                        <div class="mt-3 text-start">
                            <strong>Errors/Warnings:</strong>
                            <ul class="text-danger small" style="max-height: 200px; overflow-y: auto;">
                                ${data.errors.map(err => `<li>${err}</li>`).join('')}
                            </ul>
                        </div>
                    `;
                }

                Swal.fire({
                    icon: 'success',
                    title: 'Import Successful!',
                    background: '#0f172a',
                    color: '#e0e0e0',
                    iconColor: '#4ade80',
                    html: `
                        <p>${data.message}</p>
                        <div class="mt-2">
                            <span class="badge bg-success">${data.imported} Imported</span>
                            <span class="badge bg-warning text-dark">${data.skipped} Skipped</span>
                        </div>
                        ${errorHtml}
                    `,
                    confirmButtonText: 'OK'
                }).then(() => location.reload());
            } else {
                throw new Error(data.message || 'Import failed');
            }
        })
        .catch(error => {
            Swal.fire({
                icon: 'error',
                title: 'Import Failed',
                background: '#0f172a',
                color: '#e0e0e0',
                text: error.message || 'An error occurred while importing the file.'
            });
        });
}

