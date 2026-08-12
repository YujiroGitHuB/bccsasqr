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

            // This was `.settings-card:nth-child(2) .status-text` —
            // dependent on the card's position, so it silently updated
            // the wrong row once anything was added before it.
            const statusText = document.getElementById('attendanceLockStatus');
            if (statusText) {
                const locked = newStatus === '1';
                statusText.className = 'set-badge ' + (locked ? 'off' : 'on');
                statusText.innerHTML = locked
                    ? '<i class="bi bi-lock-fill"></i> Locked'
                    : '<i class="bi bi-unlock-fill"></i> Unlocked';
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