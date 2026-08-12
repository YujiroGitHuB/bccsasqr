document.addEventListener('DOMContentLoaded', () => {

    const systemLogo = document.getElementById('systemLogo');
    const logoPreview = document.getElementById('logoPreview');
    const logoFileName = document.getElementById('logoFileName');
    const logoReset = document.getElementById('logoReset');
    const systemConfigForm = document.getElementById('systemConfigForm');

    // One dialog look across the whole app — sky/cyan on a #16161a
    // surface. This used to be a #1e1e2f background with #e11d48
    // buttons: two colors found nowhere else in the app.
    const swalBase = {
        background: '#16161a',
        color: '#f1f5f9',
        confirmButtonColor: '#0ea5e9',
    };

    // The plate's original contents — this is what Undo restores. It
    // has to be saved before anything is picked, because it is the
    // only copy once the preview has replaced innerHTML.
    const originalPlate = logoPreview.innerHTML;
    const originalPlateEmpty = logoPreview.classList.contains('is-empty');

    const showOriginalLogo = () => {
        logoPreview.innerHTML = originalPlate;
        logoPreview.classList.toggle('is-empty', originalPlateEmpty);
        logoFileName.textContent = 'Keeping the current logo';
        logoFileName.classList.add('is-idle');
        logoReset.hidden = true;
    };

    // 🔹 Real-time Logo Preview
    systemLogo.addEventListener('change', (e) => {
        const file = e.target.files[0];

        // The file dialog was cancelled — nothing was picked, so go
        // back to the old logo rather than leaving the user looking at
        // a preview of a file that will never be sent.
        if (!file) {
            showOriginalLogo();
            return;
        }

        const reader = new FileReader();
        reader.onload = (event) => {
            logoPreview.classList.remove('is-empty');
            logoPreview.innerHTML =
                `<img src="${event.target.result}" alt="New logo preview">`;
        };
        reader.readAsDataURL(file);

        logoFileName.textContent = file.name;
        logoFileName.classList.remove('is-idle');
        logoReset.hidden = false;
    });

    // 🔹 Undo — empties the field, so the form sends no file and the
    // old logo stays (crud/update_system_config.php sees
    // `UPLOAD_ERR_NO_FILE`).
    logoReset.addEventListener('click', () => {
        systemLogo.value = '';
        showOriginalLogo();
        systemLogo.focus();
    });

    // 🔹 Handle Form Submission
    systemConfigForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const formData = new FormData(systemConfigForm);

        fetch('../crud/update_system_config.php', {
            method: 'POST',
            body: formData
        })
            .then(res => res.json())
            .then(data => {
                if (data.success) {
                    // ✅ Success Toast
                    Swal.fire({
                        ...swalBase,
                        icon: 'success',
                        title: 'System Updated!',
                        text: data.message,
                        toast: true,
                        position: 'top-end',
                        showConfirmButton: false,
                        timer: 2000,
                        timerProgressBar: true,
                        iconColor: '#4ade80',
                        didOpen: (toast) => {
                            toast.addEventListener('mouseenter', Swal.stopTimer);
                            toast.addEventListener('mouseleave', Swal.resumeTimer);
                        }
                    });

                    // Close modal smoothly
                    const modal = bootstrap.Modal.getInstance(document.getElementById('systemConfigModal'));
                    modal.hide();

                    // Optional: reload to apply new logo/title
                    setTimeout(() => location.reload(), 2000);

                } else {
                    // ❌ Error
                    Swal.fire({
                        ...swalBase,
                        icon: 'error',
                        title: 'Update Failed',
                        text: data.message || 'Something went wrong while saving settings.',
                        iconColor: '#f87171',
                    });
                }
            })
            .catch(err => {
                console.error(err);
                Swal.fire({
                    ...swalBase,
                    icon: 'error',
                    title: 'Oops...',
                    text: 'Something went wrong. Please try again later.',
                    iconColor: '#f87171',
                });
            });
    });

});
