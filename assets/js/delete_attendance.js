$(document).ready(function () {
    var table = $('#example').DataTable();

    // ── Select + Delete Selected ────────────────────────────
    var selSwal = {
        background: '#121212', color: '#e0e0e0', iconColor: '#00e5ff',
        showCancelButton: true, confirmButtonText: 'Delete', cancelButtonText: 'Cancel',
        reverseButtons: true,
        customClass: {
            popup: 'modern-dark-popup', title: 'modern-dark-title',
            htmlContainer: 'modern-dark-text', confirmButton: 'modern-dark-confirm',
            cancelButton: 'modern-dark-cancel'
        }
    };

    function selectedIds() {
        var ids = [];
        table.rows({ search: 'applied' }).nodes().to$().find('.rowCheck:checked').each(function () {
            ids.push($(this).val());
        });
        return ids;
    }

    function refreshSelectBar() {
        var checks  = table.rows({ search: 'applied' }).nodes().to$().find('.rowCheck');
        var checked = checks.filter(':checked').length;
        var total   = checks.length;

        $('#deleteSelected').prop('disabled', checked === 0)
            .find('.btn-text').text(checked > 0 ? 'Delete Selected (' + checked + ')' : 'Delete Selected');

        var sa = $('#selectAllAttendance');
        sa.prop('checked', total > 0 && checked === total);
        sa.prop('indeterminate', checked > 0 && checked < total);
    }

    $('#selectAllAttendance').on('change', function () {
        var checked = this.checked;
        table.rows({ search: 'applied' }).nodes().to$().find('.rowCheck').prop('checked', checked);
        refreshSelectBar();
    });

    $(document).on('change', '.rowCheck', refreshSelectBar);
    table.on('draw', refreshSelectBar);

    $('#deleteSelected').on('click', function () {
        var ids = selectedIds();
        if (ids.length === 0) return;

        Swal.fire({
            ...selSwal,
            title: 'Delete Selected?',
            text: 'Remove ' + ids.length + ' selected attendance record(s)?',
            icon: 'warning'
        }).then(function (result) {
            if (!result.isConfirmed) return;
            $.ajax({
                url: '../crud/delete_selected_attendance.php',
                method: 'POST',
                data: { ids: ids },
                success: function (response) {
                    var res = typeof response === 'string' ? JSON.parse(response) : response;
                    if (res.success) {
                        ids.forEach(function (id) { table.row($('#row-' + id)).remove(); });
                        table.draw(false);
                        refreshSelectBar();
                        Swal.fire({
                            ...selSwal, icon: 'success', title: 'Deleted!',
                            text: (res.rows_deleted || ids.length) + ' record(s) removed.',
                            timer: 1500, showConfirmButton: false
                        });
                    } else {
                        Swal.fire({ ...selSwal, icon: 'error', title: 'Error!', text: res.message || 'Failed to delete selected.' });
                    }
                },
                error: function () {
                    Swal.fire({ ...selSwal, icon: 'error', title: 'Error!', text: 'Something went wrong.' });
                }
            });
        });
    });

    // Delete single record
    $(document).on('click', '.btn-delete', function () {
        const id = $(this).data('id');

        const swalOptions = {
            background: '#121212',
            color: '#e0e0e0',
            iconColor: '#00e5ff',
            showCancelButton: true,
            confirmButtonText: 'Delete',
            cancelButtonText: 'Cancel',
            reverseButtons: true,
            customClass: {
                popup: 'modern-dark-popup',
                title: 'modern-dark-title',
                htmlContainer: 'modern-dark-text',
                confirmButton: 'modern-dark-confirm',
                cancelButton: 'modern-dark-cancel'
            }
        };

        Swal.fire({
            ...swalOptions,
            title: 'Delete Record?',
            text: 'Are you sure you want to remove this attendance record?',
            icon: 'warning'
        }).then((result) => {
            if (result.isConfirmed) {
                $.ajax({
                    url: '../crud/delete_attendance.php',
                    method: 'POST',
                    data: { id: id },
                    success: function (response) {
                        const res = JSON.parse(response);
                        if (res.success) {
                            $('#row-' + id).fadeOut(500, function () {
                                $(this).remove();
                            });
                            Swal.fire({
                                ...swalOptions,
                                icon: 'success',
                                title: 'Deleted!',
                                text: 'Record has been removed.',
                                timer: 1500,
                                showConfirmButton: false
                            });
                        } else {
                            Swal.fire({
                                ...swalOptions,
                                icon: 'error',
                                title: 'Error!',
                                text: 'Failed to delete record.'
                            });
                        }
                    },
                    error: function () {
                        Swal.fire({
                            ...swalOptions,
                            icon: 'error',
                            title: 'Error!',
                            text: 'Something went wrong.'
                        });
                    }
                });
            }
        });
    });

    // Delete all records
    $('#deleteAll').click(function () {
        const swalOptions = {
            background: '#121212',
            color: '#e0e0e0',
            iconColor: '#00e5ff',
            showCancelButton: true,
            confirmButtonText: 'Delete All',
            cancelButtonText: 'Cancel',
            reverseButtons: true,
            customClass: {
                popup: 'modern-dark-popup',
                title: 'modern-dark-title',
                htmlContainer: 'modern-dark-text',
                confirmButton: 'modern-dark-confirm',
                cancelButton: 'modern-dark-cancel'
            }
        };

        Swal.fire({
            ...swalOptions,
            title: 'Delete All Records?',
            text: 'This will remove all attendance records permanently!',
            icon: 'warning'
        }).then((result) => {
            if (result.isConfirmed) {
                $.ajax({
                    url: '../crud/delete_all_attendance.php',
                    method: 'POST',
                    success: function (response) {
                        const res = JSON.parse(response);
                        if (res.success) {
                            $('#example tbody').fadeOut(500, function () {
                                $(this).empty().fadeIn(300);
                            });
                            Swal.fire({
                                ...swalOptions,
                                icon: 'success',
                                title: 'Deleted!',
                                text: 'All attendance records have been cleared.',
                                timer: 1500,
                                showConfirmButton: false
                            });
                        } else {
                            Swal.fire({
                                ...swalOptions,
                                icon: 'error',
                                title: 'Error!',
                                text: 'Failed to delete all records.'
                            });
                        }
                    },
                    error: function () {
                        Swal.fire({
                            ...swalOptions,
                            icon: 'error',
                            title: 'Error!',
                            text: 'Something went wrong.'
                        });
                    }
                });
            }
        });
    });
});
