document.addEventListener('DOMContentLoaded', function () {
    const selectAllCheckbox = document.getElementById('selectAllCheckbox');
    const deleteSelectedBtn = document.getElementById('deleteSelectedBtn');
    const selectedCountSpan = document.getElementById('selectedCount');

    // Helper: get all currently checked row checkboxes
    function getCheckedIds() {
        return Array.from(document.querySelectorAll('.row-checkbox:checked'))
            .map(cb => cb.value);
    }

    // Update button visibility and count
    function updateDeleteBtn() {
        const ids = getCheckedIds();
        selectedCountSpan.textContent = ids.length;

        if (ids.length > 0) {
            deleteSelectedBtn.classList.remove('d-none');
        } else {
            deleteSelectedBtn.classList.add('d-none');
        }

        // Update select-all checkbox state
        const allCheckboxes = document.querySelectorAll('.row-checkbox');
        if (allCheckboxes.length > 0) {
            selectAllCheckbox.checked        = ids.length === allCheckboxes.length;
            selectAllCheckbox.indeterminate  = ids.length > 0 && ids.length < allCheckboxes.length;
        }
    }

    // Select All / Deselect All
    if (selectAllCheckbox) {
        selectAllCheckbox.addEventListener('change', function () {
            document.querySelectorAll('.row-checkbox').forEach(cb => {
                cb.checked = selectAllCheckbox.checked;
            });
            updateDeleteBtn();
        });
    }

    // Individual checkbox change — use event delegation for DataTables compatibility
    document.addEventListener('change', function (e) {
        if (e.target.classList.contains('row-checkbox')) {
            updateDeleteBtn();
        }
    });

    // Delete Selected Button click
    if (deleteSelectedBtn) {
        deleteSelectedBtn.addEventListener('click', function () {
            const ids = getCheckedIds();

            if (ids.length === 0) return;

            Swal.fire({
                title: 'Delete Selected Students?',
                html: `You are about to delete <strong>${ids.length}</strong> student(s).<br>This action cannot be undone!`,
                icon: 'warning',
                background: '#0f172a',
                color: '#e0e0e0',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#3085d6',
                confirmButtonText: 'Yes, delete selected!',
                cancelButtonText: 'Cancel'
            }).then((result) => {
                if (result.isConfirmed) {
                    Swal.fire({
                        title: 'Deleting...',
                        text: 'Please wait',
                        allowOutsideClick: false,
                        background: '#0f172a',
                        color: '#e0e0e0',
                        didOpen: () => Swal.showLoading()
                    });

                    $.ajax({
                        url: '../crud/delete_selected_students.php',
                        type: 'POST',
                        dataType: 'json',
                        data: { ids: ids },
                        success: function (response) {
                            if (response.success) {
                                Swal.fire({
                                    icon: 'success',
                                    title: 'Deleted!',
                                    background: '#0f172a',
                                    color: '#e0e0e0',
                                    text: response.message,
                                    timer: 2000,
                                    showConfirmButton: false
                                }).then(() => {
                                    location.reload();
                                });
                            } else {
                                Swal.fire({
                                    icon: 'error',
                                    title: 'Error!',
                                    background: '#0f172a',
                                    color: '#e0e0e0',
                                    text: response.message
                                });
                            }
                        },
                        error: function () {
                            Swal.fire({
                                icon: 'error',
                                title: 'Error!',
                                background: '#0f172a',
                                color: '#e0e0e0',
                                text: 'Failed to delete selected students. Please try again.'
                            });
                        }
                    });
                }
            });
        });
    }
});