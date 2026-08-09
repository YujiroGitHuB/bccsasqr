document.getElementById('addStudentForm').addEventListener('submit', function (e) {
    e.preventDefault();
    const formData = new FormData(this);

    fetch('../crud/add_students.php', {
        method: 'POST',
        body: formData
    })
        .then(res => res.json())
        .then(data => {
            let swalOptions = {
                background: '#1e1e1e', // dark background
                color: '#ffffff', // white text
                customClass: {
                    popup: 'dark-popup',
                    title: 'dark-title',
                    confirmButton: 'dark-confirm'
                }
            };

            if (data.status === 'success') {
                Swal.fire({
                    ...swalOptions,
                    icon: 'success',
                    title: 'Student Added',
                    text: 'The new student has been added successfully!',
                    timer: 1500,
                    showConfirmButton: false
                }).then(() => location.reload());
            } else if (data.status === 'duplicate') {
                Swal.fire({
                    ...swalOptions,
                    icon: 'info',
                    title: 'Duplicate',
                    text: 'This student number already exists.'
                });
            } else if (data.status === 'incomplete') {
                Swal.fire({
                    ...swalOptions,
                    icon: 'warning',
                    title: 'Warning',
                    text: 'Please fill in all fields!'
                });
            } else {
                Swal.fire({
                    ...swalOptions,
                    icon: 'error',
                    title: 'Error',
                    text: 'Failed to add student. Try again.'
                });
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire({
                background: '#1e1e1e',
                color: '#fff',
                icon: 'error',
                title: 'Error',
                text: 'Something went wrong. Please try again.'
            });
        });
});
