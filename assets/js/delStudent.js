// Delegated: ginagawa na ng DataTables ang mga row mula sa JSON, kaya
// wala pang buton sa DOM kapag na-load ang script na ito — at nagbabago
// ang mga row tuwing lumilipat ng page o naghahanap.
document.addEventListener('click', function (e) {
    const button = e.target.closest('.btn-deletes');
    if (button) {
        const studentId = button.getAttribute('data-id');

        // Dark theme base options
        const swalOptions = {
            background: '#1e1e1e',
            color: '#ffffff',
            customClass: {
                popup: 'dark-popup',
                title: 'dark-title',
                confirmButton: 'dark-confirm'
            }
        };

        Swal.fire({
            ...swalOptions,
            title: 'Are you sure?',
            text: "This student record will be permanently deleted.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Yes, delete it!',
            cancelButtonText: 'Cancel'
        }).then((result) => {
            if (result.isConfirmed) {
                fetch('../crud/delete_students.php', {
                    method: 'POST',
                    body: new URLSearchParams({
                        id: studentId
                    })
                })
                    .then(res => res.json())
                    .then(data => {
                        if (data.status === 'success') {
                            Swal.fire({
                                ...swalOptions,
                                icon: 'success',
                                title: 'Deleted!',
                                text: 'Student record removed successfully.',
                                timer: 1500,
                                showConfirmButton: false
                            });

                            // Smoothly remove the row from table.
                            // Kailangang dumaan sa DataTables API — kung ang <tr>
                            // lang ang tatanggalin, nasa internal data pa rin ito
                            // at muling lilitaw pagkalipat ng page o paghahanap.
                            const row = document.getElementById('row-' + studentId);
                            if (row) {
                                row.classList.add('animate__animated', 'animate__fadeOut');
                                setTimeout(() => {
                                    if (window.jQuery && $.fn.DataTable.isDataTable('#stud_tbl')) {
                                        $('#stud_tbl').DataTable().row(row).remove().draw(false);
                                    } else {
                                        row.remove();
                                    }
                                }, 500);
                            }
                        } else {
                            Swal.fire({
                                ...swalOptions,
                                icon: 'error',
                                title: 'Error',
                                text: 'Failed to delete record.'
                            });
                        }
                    })
                    .catch(err => {
                        console.error(err);
                        Swal.fire({
                            ...swalOptions,
                            icon: 'error',
                            title: 'Error',
                            text: 'Something went wrong.'
                        });
                    });
            }
        });
    }
});
