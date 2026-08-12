// ============================================================
//  MANAGE USERS
//
//  DataTables owns the table (paging + sorting). That matters:
//  rows on another page are NOT in the DOM. The old filter here
//  set `row.style.display = 'none'` on the rows that were in the
//  DOM — so a user on page 2 was never found by a search, and
//  DataTables wiped the hiding on every sort or page change.
//
//  Instead, the search now goes through the DataTables API.
// ============================================================

let usersTable = null;

const swalDark = { background: '#0f172a', color: '#e2e8f0' };

const userToast = (icon, title) =>
    Swal.fire(Object.assign({
        toast: true,
        position: 'top-end',
        icon: icon,
        title: title,
        showConfirmButton: false,
        timer: 2400,
        timerProgressBar: true
    }, swalDark));

// ── Filter ng role/status ────────────────────────────────────
// Reads the data-* off the <tr> itself, so it works even for rows
// that have not been rendered yet.
$.fn.dataTable.ext.search.push(function (settings, data, dataIndex) {
    if (settings.nTable.id !== 'usersTable') return true;

    const row = settings.aoData[dataIndex].nTr;
    if (!row) return true;

    const roleFilter   = document.getElementById('filterRole')?.value   ?? '';
    const statusFilter = document.getElementById('filterStatus')?.value ?? '';

    const role   = row.getAttribute('data-role')   ?? '';
    const status = row.getAttribute('data-status') ?? '';

    return (!roleFilter || role === roleFilter) &&
           (!statusFilter || status === statusFilter);
});

$(document).ready(function () {
    if (!$('#usersTable').length) return;

    usersTable = $('#usersTable').DataTable({
        // No 'f' (search box) — that lives in the filter bar above.
        dom: '<"row"<"col-12"tr>><"row mt-2"<"col-sm-6"i><"col-sm-6"p>>',
        pageLength: 10,
        order: [],                       // keep PHP's ORDER BY id DESC
        columnDefs: [
            { targets: [0, 6], orderable: false, searchable: false }
        ],
        language: {
            emptyTable: '<div class="empty-state">' +
                        '<i class="bi bi-person-slash"></i>' +
                        '<strong>No users found</strong>' +
                        '<span>Try resetting the filters.</span></div>',
            zeroRecords: '<div class="empty-state">' +
                         '<i class="bi bi-search"></i>' +
                         '<strong>Nothing matched your search</strong>' +
                         '<span>Try resetting the filters.</span></div>',
            info: 'Showing _START_ to _END_ of _TOTAL_ users',
            infoEmpty: 'No users to show',
            infoFiltered: '(filtered from _MAX_)'
        }
    });

    document.getElementById('searchUser')?.addEventListener('keyup', filterUsers);
    document.getElementById('filterRole')?.addEventListener('change', filterUsers);
    document.getElementById('filterStatus')?.addEventListener('change', filterUsers);

    initUserForm();
});

function filterUsers() {
    if (!usersTable) return;
    const term = document.getElementById('searchUser')?.value ?? '';
    usersTable.search(term).draw();
}

function resetFilters() {
    const search = document.getElementById('searchUser');
    const role   = document.getElementById('filterRole');
    const status = document.getElementById('filterStatus');

    if (search) search.value = '';
    if (role)   role.value   = '';
    if (status) status.value = '';

    filterUsers();
}

// ── Enable / Disable ─────────────────────────────────────────
function toggleUserStatus(userId, newStatus) {
    const row = document.querySelector(`tr[data-user-id="${userId}"]`);

    // The name comes from the row's data-name rather than being
    // passed through onclick — an apostrophe in a name (e.g.
    // "O'Brien") no longer breaks the JS string.
    const userName   = row?.getAttribute('data-name') ?? 'this user';
    const actionText = newStatus === 'disabled' ? 'Disable' : 'Enable';

    Swal.fire(Object.assign({
        title: `${actionText} User?`,
        html: `
            <p>Are you sure you want to ${actionText.toLowerCase()} <strong>${escapeHtml(userName)}</strong>?</p>
            ${newStatus === 'disabled' ? '<p class="text-warning small">This user will not be able to log in.</p>' : ''}
        `,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: newStatus === 'disabled' ? '#ef4444' : '#10b981',
        cancelButtonColor: '#6c757d',
        confirmButtonText: `Yes, ${actionText}`,
        cancelButtonText: 'Cancel'
    }, swalDark)).then((result) => {
        if (!result.isConfirmed) return;

        Swal.fire(Object.assign({
            title: 'Processing...',
            allowOutsideClick: false,
            didOpen: () => Swal.showLoading()
        }, swalDark));

        fetch('../crud/toggle_user_status.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: userId, status: newStatus })
        })
        .then(response => response.json())
        .then(data => {
            if (!data.success) {
                Swal.fire(Object.assign({ icon: 'error', title: 'Error!', text: data.message }, swalDark));
                return;
            }

            row.setAttribute('data-status', newStatus);

            const statusCell = row.querySelector('td:nth-child(5)');
            statusCell.innerHTML = newStatus === 'disabled'
                ? '<span class="status-badge status-disabled"><i class="bi bi-x-circle-fill"></i> Disabled</span>'
                : '<span class="status-badge status-active"><i class="bi bi-check-circle-fill"></i> Active</span>';

            const actionCell = row.querySelector('td:nth-child(7) .row-actions');
            const toggleBtn  = newStatus === 'disabled'
                ? `<button class="btn-enable" onclick="toggleUserStatus(${userId}, 'active')">
                       <i class="bi bi-person-check me-1"></i>Enable</button>`
                : `<button class="btn-disable" onclick="toggleUserStatus(${userId}, 'disabled')">
                       <i class="bi bi-person-x me-1"></i>Disable</button>`;
            actionCell.innerHTML =
                `<button class="btn-edit" onclick="openEditUser(${userId})">
                     <i class="bi bi-pencil"></i> Edit</button>` + toggleBtn;

            // Required: DataTables keeps its own copy of every cell's
            // contents. Without telling it about the change, it would
            // still search and sort against the old "Active".
            if (usersTable) usersTable.row(row).invalidate('dom').draw(false);

            setCount('activeCount', data.active_count);
            setCount('disabledCount', data.disabled_count);
            setCount('totalCount', data.total_count);

            userToast('success', data.message);
        })
        .catch(() => {
            Swal.fire(Object.assign({
                icon: 'error',
                title: 'Network Error!',
                text: 'Could not connect to the server. Please try again.'
            }, swalDark));
        });
    });
}

// ── Add / Edit ───────────────────────────────────────────────
function openAddUser() {
    const modal = getUserModal();
    if (!modal) return;

    document.getElementById('formUserId').value = '';
    document.getElementById('formName').value   = '';
    document.getElementById('formEmail').value  = '';
    document.getElementById('formPassword').value = '';
    document.querySelector('input[name="role"][value="instructor"]').checked = true;

    setRoleLock(false);
    document.getElementById('formIcon').className     = 'bi bi-person-plus-fill';
    document.getElementById('formTitle').textContent  = 'Add User';
    document.getElementById('formSubtitle').textContent = 'Create a new account that can sign in to the system.';
    document.getElementById('passwordHint').textContent = '(min. 8 characters)';
    document.getElementById('formPassword').placeholder = 'At least 8 characters';
    document.getElementById('formPassword').required    = true;
    document.getElementById('formSubmit').innerHTML     = '<i class="bi bi-person-plus"></i> Create User';
    showFormError('');

    modal.show();
}

function openEditUser(userId) {
    const row = document.querySelector(`tr[data-user-id="${userId}"]`);
    if (!row) return;

    const modal = getUserModal();
    if (!modal) return;

    const isSelf = row.getAttribute('data-self') === '1';

    document.getElementById('formUserId').value = userId;
    document.getElementById('formName').value   = row.getAttribute('data-name')  ?? '';
    document.getElementById('formEmail').value  = row.getAttribute('data-email') ?? '';
    document.getElementById('formPassword').value = '';

    const role = row.getAttribute('data-role') ?? 'instructor';
    const roleInput = document.querySelector(`input[name="role"][value="${role}"]`);
    if (roleInput) roleInput.checked = true;

    // The server forbids this too — checked here only to save a
    // round trip before finding out.
    setRoleLock(isSelf);

    document.getElementById('formIcon').className     = 'bi bi-pencil-square';
    document.getElementById('formTitle').textContent  = 'Edit User';
    document.getElementById('formSubtitle').textContent = 'Leave the password blank to keep the current one.';
    document.getElementById('passwordHint').textContent = '(optional — leave blank to keep current)';
    document.getElementById('formPassword').placeholder = 'Leave blank to keep current password';
    document.getElementById('formPassword').required    = false;
    document.getElementById('formSubmit').innerHTML     = '<i class="bi bi-check2-circle"></i> Save Changes';
    showFormError('');

    modal.show();
}

function initUserForm() {
    const form = document.getElementById('userForm');
    if (!form) return;

    document.getElementById('openAddUser')?.addEventListener('click', openAddUser);

    const pw  = document.getElementById('formPassword');
    const eye = document.getElementById('toggleFormPassword');
    eye?.addEventListener('click', function () {
        const show = pw.type === 'password';
        pw.type = show ? 'text' : 'password';
        this.innerHTML = show ? '<i class="bi bi-eye-slash"></i>' : '<i class="bi bi-eye"></i>';
        this.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
    });

    pw?.addEventListener('input', () => showFormError(''));

    form.addEventListener('submit', function (e) {
        e.preventDefault();

        const isNew = document.getElementById('formUserId').value === '';
        const value = pw.value;

        if (isNew && value === '') {
            showFormError('A password is required for a new user.');
            return;
        }
        if (value !== '' && value.length < 8) {
            showFormError('Password must be at least 8 characters.');
            return;
        }
        showFormError('');

        const btn      = document.getElementById('formSubmit');
        const original = btn.innerHTML;
        btn.disabled   = true;
        btn.innerHTML  = '<i class="bi bi-hourglass-split"></i> Saving...';

        const fd = new FormData(form);
        // Browsers do not submit disabled inputs. When the role picker
        // is locked (your own account) `role` goes missing from the
        // request and the server rejects it — so the current value is
        // added back by hand.
        if (!fd.has('role')) {
            const checked = document.querySelector('input[name="role"]:checked');
            if (checked) fd.append('role', checked.value);
        }

        fetch('../crud/save_user.php', { method: 'POST', body: fd })
            .then(res => res.json())
            .then(data => {
                if (data.status !== 'success') {
                    showFormError(data.message);
                    btn.disabled  = false;
                    btn.innerHTML = original;
                    return;
                }

                userToast('success', data.message);
                // Full reload: the change touches the counts, the role
                // badge and the row order — safer than patching each
                // of them in the DOM.
                setTimeout(() => location.reload(), 900);
            })
            .catch(() => {
                showFormError('Could not reach the server. Please try again.');
                btn.disabled  = false;
                btn.innerHTML = original;
            });
    });
}

// ── Helpers ──────────────────────────────────────────────────
function getUserModal() {
    const el = document.getElementById('userFormModal');
    if (!el || typeof bootstrap === 'undefined') return null;
    return bootstrap.Modal.getOrCreateInstance(el);
}

function setRoleLock(locked) {
    document.querySelectorAll('input[name="role"]').forEach(r => { r.disabled = locked; });
    const note = document.getElementById('roleNote');
    if (note) note.style.display = locked ? 'flex' : 'none';
}

function setCount(id, value) {
    const el = document.getElementById(id);
    if (el && value !== undefined) el.textContent = value;
}

function showFormError(msg) {
    const el = document.getElementById('formError');
    if (!el) return;
    el.textContent = msg;
    el.classList.toggle('show', !!msg);
}

function escapeHtml(str) {
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
}
