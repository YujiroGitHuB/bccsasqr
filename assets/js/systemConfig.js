document.addEventListener('DOMContentLoaded', () => {

    const systemLogo = document.getElementById('systemLogo');
    const logoPreview = document.getElementById('logoPreview');
    const logoFileName = document.getElementById('logoFileName');
    const logoReset = document.getElementById('logoReset');
    const systemConfigForm = document.getElementById('systemConfigForm');

    // Iisang anyo ng dialog sa buong app — sky/cyan, ibabaw na
    // #16161a. Dati ay #1e1e2f na likod at #e11d48 na butones dito:
    // dalawang kulay na wala kahit saan sa natitirang bahagi ng app.
    const swalBase = {
        background: '#16161a',
        color: '#f1f5f9',
        confirmButtonColor: '#0ea5e9',
    };

    // Ang unang laman ng plate — ito ang ibinabalik ng Undo. Kailangan
    // itong sagipin bago pa man may mapili, dahil ito na ang tanging
    // kopya kapag napalitan na ng preview ang innerHTML.
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

        // Kinansela ang dialog ng file — walang napili, kaya balik sa
        // dating logo sa halip na maiwang nakatingin sa preview ng
        // file na hindi na naman ipapadala.
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

    // 🔹 Undo — ibinabalik ang patlang sa walang laman, kaya hindi na
    // nagpapadala ng file ang form at nananatili ang lumang logo
    // (`UPLOAD_ERR_NO_FILE` ang nakikita ng crud/update_system_config.php).
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
