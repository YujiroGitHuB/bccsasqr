const toggle = document.getElementById('holo-toggle');
const lockStatusInput = document.getElementById('lock_status');

toggle.addEventListener('change', () => {
    const newStatus = toggle.checked ? 'true' : 'false';
    lockStatusInput.value = newStatus;

    // Send AJAX request
    fetch(window.location.href, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'lock_status=' + encodeURIComponent(newStatus)
    })
        .then(response => response.text())
        .then(data => {
            const toastText = newStatus === 'true' ? 'Locked' : 'Unlocked';

            Swal.fire({
                icon: 'success',
                title: toastText, // show readable text
                toast: true,
                position: 'top-end',
                showConfirmButton: false,
                timer: 2000,
                background: '#0f172a',
                color: '#e2e8f0'
            });


            // Sa id na, hindi na sa UNANG `.status-text` sa page —
            // nasisira iyon sa sandaling magbago ang pagkakasunod-sunod
            // ng mga hanay.
            const statusText = document.getElementById('pageLockStatus');
            if (statusText) {
                const locked = newStatus === 'true';
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
            toggle.checked = !toggle.checked;
        });
});