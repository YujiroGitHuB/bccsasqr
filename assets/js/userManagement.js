function toggleUserStatus(userId, newStatus, userName) {
    const action     = newStatus === 'disabled' ? 'disable' : 'enable';
    const actionText = newStatus === 'disabled' ? 'Disable' : 'Enable';

    Swal.fire({
        title: `${actionText} User?`,
        html: `
            <p>Are you sure you want to ${action} <strong>${userName}</strong>?</p>
            ${newStatus === 'disabled' ? '<p class="text-warning small">This user will not be able to log in.</p>' : ''}
        `,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: newStatus === 'disabled' ? '#ef4444' : '#10b981',
        cancelButtonColor: '#6c757d',
        confirmButtonText: `Yes, ${actionText}`,
        cancelButtonText: 'Cancel',
        background: '#0f172a',
        color: '#e2e8f0'
    }).then((result) => {
        if (!result.isConfirmed) return;

        Swal.fire({
            title: 'Processing...',
            allowOutsideClick: false,
            background: '#0f172a',
            color: '#e2e8f0',
            didOpen: () => Swal.showLoading()
        });

        fetch('../crud/toggle_user_status.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: userId, status: newStatus })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const row = document.querySelector(`tr[data-user-id="${userId}"]`);
                row.setAttribute('data-status', newStatus);

                // ── Update status badge (custom classes) ──
                const statusCell = row.querySelector('td:nth-child(5)');
                if (newStatus === 'disabled') {
                    statusCell.innerHTML = `
                        <span class="status-badge status-disabled">
                            <i class="bi bi-x-circle-fill"></i> Disabled
                        </span>`;
                } else {
                    statusCell.innerHTML = `
                        <span class="status-badge status-active">
                            <i class="bi bi-check-circle-fill"></i> Active
                        </span>`;
                }

                // ── Update action button (custom classes) ──
                const actionCell = row.querySelector('td:nth-child(7)');
                if (newStatus === 'disabled') {
                    actionCell.innerHTML = `
                        <button class="btn-enable" onclick="toggleUserStatus(${userId}, 'active', '${userName}')">
                            <i class="bi bi-person-check me-1"></i>Enable
                        </button>`;
                } else {
                    actionCell.innerHTML = `
                        <button class="btn-disable" onclick="toggleUserStatus(${userId}, 'disabled', '${userName}')">
                            <i class="bi bi-person-x me-1"></i>Disable
                        </button>`;
                }

                // ── Update stat counts ──
                document.getElementById('activeCount').textContent   = data.active_count;
                document.getElementById('disabledCount').textContent = data.disabled_count;
                document.getElementById('totalCount').textContent    = data.total_count;

                Swal.fire({
                    icon: 'success',
                    title: 'Success!',
                    text: data.message,
                    timer: 2000,
                    showConfirmButton: false,
                    background: '#0f172a',
                    color: '#e2e8f0'
                });
            } else {
                Swal.fire({
                    icon: 'error',
                    title: 'Error!',
                    text: data.message,
                    background: '#0f172a',
                    color: '#e2e8f0'
                });
            }
        })
        .catch(() => {
            Swal.fire({
                icon: 'error',
                title: 'Network Error!',
                text: 'Could not connect to the server. Please try again.',
                background: '#0f172a',
                color: '#e2e8f0'
            });
        });
    });
}

// ── Search & Filter ───────────────────────────────────────────
document.getElementById('searchUser')?.addEventListener('keyup', filterUsers);
document.getElementById('filterRole')?.addEventListener('change', filterUsers);
document.getElementById('filterStatus')?.addEventListener('change', filterUsers);

function filterUsers() {
    const searchTerm   = document.getElementById('searchUser').value.toLowerCase();
    const roleFilter   = document.getElementById('filterRole').value;
    const statusFilter = document.getElementById('filterStatus').value;

    document.querySelectorAll('#usersTable tbody tr').forEach(row => {
        const name   = row.querySelector('td:nth-child(2)')?.textContent.toLowerCase() ?? '';
        const email  = row.querySelector('td:nth-child(3)')?.textContent.toLowerCase() ?? '';
        const role   = row.getAttribute('data-role')   ?? '';
        const status = row.getAttribute('data-status') ?? '';

        const matchesSearch = name.includes(searchTerm) || email.includes(searchTerm);
        const matchesRole   = !roleFilter   || role   === roleFilter;
        const matchesStatus = !statusFilter || status === statusFilter;

        row.style.display = (matchesSearch && matchesRole && matchesStatus) ? '' : 'none';
    });
}

function resetFilters() {
    document.getElementById('searchUser').value  = '';
    document.getElementById('filterRole').value  = '';
    document.getElementById('filterStatus').value = '';
    filterUsers();
}