function editStudent(id, student_no, fullname, course, section) {
    document.getElementById('edit_id').value = id;
    document.getElementById('edit_student_no').value = student_no;
    document.getElementById('edit_fullname').value = fullname;
    document.getElementById('edit_course').value = course;
    document.getElementById('edit_section').value = section;

    const modal = new bootstrap.Modal(document.getElementById('editModal'));
    modal.show();
}

document.getElementById('updateStudentForm').addEventListener('submit', function (e) {
    e.preventDefault();
    const formData = new FormData(this);

    fetch('../crud/update_students.php', {
        method: 'POST',
        body: formData
    })
        .then(res => res.json())
        .then(data => {
            // Reusable dark theme options
            const swalOptions = {
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
                    title: 'Updated!',
                    text: 'Student record updated successfully.',
                    timer: 1500,
                    showConfirmButton: false
                }).then(() => location.reload());
            } else if (data.status === 'duplicate') {
                Swal.fire({
                    ...swalOptions,
                    icon: 'info',
                    title: 'Duplicate',
                    text: 'Student number already exists.'
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
                    text: 'Failed to update student. Try again.'
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
