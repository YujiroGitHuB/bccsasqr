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


            // Update the status text on the page dynamically
            const statusText = document.querySelector('.status-text');
            if (newStatus === 'true') {
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
            toggle.checked = !toggle.checked;
        });
});