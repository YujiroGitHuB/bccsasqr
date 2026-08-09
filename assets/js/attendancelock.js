// attendanceLock.js - Handle attendance form lock/unlock toggle

const attendanceToggle = document.getElementById('attendance-toggle');
const attendanceLockStatusInput = document.getElementById('attendance_lock_status');

attendanceToggle.addEventListener('change', () => {
    const newStatus = attendanceToggle.checked ? '1' : '0';
    attendanceLockStatusInput.value = newStatus;

    // Send AJAX request
    fetch(window.location.href, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'attendance_lock_status=' + encodeURIComponent(newStatus)
    })
        .then(response => response.text())
        .then(data => {
            const toastText = newStatus === '1' ? 'Attendance Locked' : 'Attendance Unlocked';

            Swal.fire({
                icon: 'success',
                title: toastText,
                toast: true,
                position: 'top-end',
                showConfirmButton: false,
                timer: 2000,
                background: '#0f172a',
                color: '#e2e8f0'
            });

            // Update the status text on the page dynamically
            const statusText = document.querySelector('.settings-card:nth-child(2) .status-text');
            if (newStatus === '1') {
                statusText.innerHTML = 'Current Status: <span class="locked"><i class="bi bi-lock"></i> LOCKED</span>';
            } else {
                statusText.innerHTML = 'Current Status: <span class="unlocked"><i class="bi bi-unlock-fill"></i> UNLOCKED</span>';
            }
        })
        .catch(err => {
            Swal.fire({
                toast: true,
                position: 'top-end',
                icon: 'error',
                title: 'Failed to update!',
                showConfirmButton: false,
                timer: 1500
            });
            // Revert toggle if failed
            attendanceToggle.checked = !attendanceToggle.checked;
        });
});