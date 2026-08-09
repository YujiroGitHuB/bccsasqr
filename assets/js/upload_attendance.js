document.addEventListener('DOMContentLoaded', function () {
    const uploadBtn = document.getElementById('uploadCSV');
    const downloadBtn = document.getElementById('downloadTemplate');
    const uploadModal = new bootstrap.Modal(document.getElementById('uploadModal'));
    const uploadForm = document.getElementById('uploadForm');
    const submitBtn = document.getElementById('uploadBtn');
    const csvFileInput = document.querySelector('input[name="csv_file"]');

    // Download Template Button
    if (downloadBtn) {
        downloadBtn.addEventListener('click', function () {
            window.location.href = '../crud/download_template.php';
        });
    }

    // Validate file on change
    if (csvFileInput) {
        csvFileInput.addEventListener('change', function (e) {
            const file = e.target.files[0];

            if (file) {
                // Validate file type
                if (!file.name.endsWith('.csv')) {
                    Swal.fire({
                        icon: 'error',
                        title: 'Invalid File',
                        background: '#0f172a',
                        color: '#e0e0e0',
                        iconColor: '#ed360dff',
                        text: 'Please select a CSV file only'
                    });
                    csvFileInput.value = '';
                    return;
                }

                // Validate file size (5MB max)
                if (file.size > 5 * 1024 * 1024) {
                    Swal.fire({
                        icon: 'error',
                        title: 'File Too Large',
                        background: '#0f172a',
                        color: '#e0e0e0',
                        iconColor: '#ed360dff',
                        text: 'File size must be less than 5MB'
                    });
                    csvFileInput.value = '';
                    return;
                }
            }
        });
    }

    // Upload Button Click
    if (submitBtn) {
        submitBtn.addEventListener('click', function () {
            // Validate form
            if (!uploadForm.checkValidity()) {
                uploadForm.reportValidity();
                return;
            }

            const file = csvFileInput.files[0];
            const dateInput = document.querySelector('input[name="attendance_date"]').value;
            const timeInput = document.querySelector('input[name="time_in"]').value;
            const subjectSelect = document.getElementById('subjectSelect');
            const selectedSubject = subjectSelect.options[subjectSelect.selectedIndex];

            if (!file) {
                Swal.fire({
                    icon: 'error',
                    title: 'No File Selected',
                    background: '#0f172a',
                    color: '#e0e0e0',
                    iconColor: '#ed360dff',
                    text: 'Please select a CSV file to upload'
                });
                return;
            }

            if (!subjectSelect.value) {
                Swal.fire({
                    icon: 'error',
                    title: 'No Subject Selected',
                    background: '#0f172a',
                    color: '#e0e0e0',
                    iconColor: '#ed360dff',
                    text: 'Please select a subject'
                });
                return;
            }

            // Format date and time
            const formattedDate = formatDate(dateInput);
            const formattedTime = formatTime(timeInput);

            // Show confirmation with subject
            Swal.fire({
                title: 'Import Attendance from CSV?',
                background: '#0f172a',
                color: '#e0e0e0',
                iconColor: '#4ade80',
                html: `
                <div class="text-start">
                    <p><strong>Subject:</strong> ${selectedSubject.dataset.name}</p>
                    <p><strong>File:</strong> ${file.name}</p>
                    <p><strong>Size:</strong> ${(file.size / 1024).toFixed(2)} KB</p>
                    <p><strong>Date:</strong> ${formattedDate}</p>
                    <p><strong>Time In:</strong> ${formattedTime}</p>
                    <p class="text-warning mt-3">
                        <i class="bi bi-exclamation-triangle"></i> 
                        Only students enrolled in <strong>${selectedSubject.dataset.name}</strong> will be recorded.
                    </p>
                </div>
            `,
                icon: 'question',
                showCancelButton: true,
                confirmButtonText: 'Yes, Import',
                cancelButtonText: 'Cancel',
                showLoaderOnConfirm: true,
                preConfirm: () => {
                    return uploadAttendance();
                },
                allowOutsideClick: () => !Swal.isLoading()
            }).then((result) => {
                if (result.isConfirmed) {
                    // Success handled in uploadAttendance function
                }
            });
        });
    }
});

// Format date from YYYY-MM-DD to readable format
function formatDate(dateString) {
    const date = new Date(dateString);
    const options = { year: 'numeric', month: 'long', day: 'numeric' };
    return date.toLocaleDateString('en-US', options);
}

// Format time from HH:MM to 12-hour format with AM/PM
function formatTime(timeString) {
    const [hours, minutes] = timeString.split(':');
    let hour = parseInt(hours);
    const ampm = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    hour = hour ? hour : 12; // 0 should be 12

    const seconds = '00'; // Default seconds

    return `${hour}:${minutes}:${seconds} ${ampm}`;
}

function uploadAttendance() {
    const form = document.getElementById('uploadForm');
    const formData = new FormData(form);

    return fetch('../crud/upload_attendance.php', {
        method: 'POST',
        body: formData
    })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                let errorHtml = '';

                // Show errors/warnings if any
                if (data.errors && data.errors.length > 0) {
                    errorHtml = `
                <div class="mt-3 text-start">
                    <strong>Errors/Warnings:</strong>
                    <ul class="text-warning small" style="max-height: 200px; overflow-y: auto;">
                        ${data.errors.map(err => `<li>${err}</li>`).join('')}
                    </ul>
                </div>
            `;
                }

                // Show skipped students if any
                let skippedHtml = '';
                if (data.skipped > 0 && data.skipped_students && data.skipped_students.length > 0) {
                    skippedHtml = `
                <div class="mt-2 text-start">
                    <strong class="text-warning">Skipped (Already Recorded):</strong>
                    <div class="small" style="max-height: 100px; overflow-y: auto;">
                        ${data.skipped_students.join(', ')}
                    </div>
                </div>
            `;
                }

                // Show not found students if any
                let notFoundHtml = '';
                if (data.not_found > 0 && data.not_found_students && data.not_found_students.length > 0) {
                    notFoundHtml = `
                <div class="mt-2 text-start">
                    <strong class="text-danger">Not Found in Database:</strong>
                    <div class="small" style="max-height: 100px; overflow-y: auto;">
                        ${data.not_found_students.join(', ')}
                    </div>
                </div>
            `;
                }

                // ✅ NEW: Show not authorized students
                let notAuthorizedHtml = '';
                if (data.not_authorized > 0 && data.not_authorized_students && data.not_authorized_students.length > 0) {
                    notAuthorizedHtml = `
                <div class="mt-2 text-start">
                    <strong class="text-danger">Not in Your Assigned Sections:</strong>
                    <div class="small" style="max-height: 100px; overflow-y: auto;">
                        ${data.not_authorized_students.join(', ')}
                    </div>
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
                    <span class="badge bg-success">${data.matched} Added</span>
                    <span class="badge bg-warning">${data.skipped} Skipped</span>
                    <span class="badge bg-danger">${data.not_found} Not Found</span>
                    <span class="badge bg-danger">${data.not_authorized || 0} Not Authorized</span>
                </div>
                ${errorHtml}
                ${skippedHtml}
                ${notFoundHtml}
                ${notAuthorizedHtml}
            `,
                    width: '600px',
                    confirmButtonText: 'OK'
                }).then(() => {
                    // Close modal
                    const modal = bootstrap.Modal.getInstance(document.getElementById('uploadModal'));
                    if (modal) {
                        modal.hide();
                    }

                    // Reset form
                    form.reset();

                    // Reload page to show new attendance
                    location.reload();
                });
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
                iconColor: '#ed360dff',
                text: error.message || 'An error occurred while importing the CSV file'
            });
        });
}
