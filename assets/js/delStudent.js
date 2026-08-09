document.querySelectorAll('.btn-deletes').forEach(button => {
    button.addEventListener('click', function () {
        const studentId = this.getAttribute('data-id');

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

                            // Smoothly remove the row from table
                            const row = document.getElementById('row-' + studentId);
                            if (row) {
                                row.classList.add('animate__animated', 'animate__fadeOut');
                                setTimeout(() => row.remove(), 500);
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
    });
});
