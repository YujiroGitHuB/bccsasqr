document.addEventListener('DOMContentLoaded', () => {

    const systemLogo = document.getElementById('systemLogo');
    const logoPreview = document.getElementById('logoPreview');
    const systemConfigForm = document.getElementById('systemConfigForm');

    // 🔹 Real-time Logo Preview
    systemLogo.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = (event) => {
                logoPreview.innerHTML = `
                    <div class="card border-0 shadow-sm rounded-3 p-2"
                         style="width:120px; height:120px; display:flex; align-items:center; justify-content:center;">
                        <img src="${event.target.result}" class="img-fluid rounded-3">
                    </div>`;
            };
            reader.readAsDataURL(file);
        }
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
                    // ✅ Success Toast (Dark Mode)
                    Swal.fire({
                        icon: 'success',
                        title: 'System Updated!',
                        text: data.message,
                        toast: true,
                        position: 'top-end',
                        showConfirmButton: false,
                        timer: 2000,
                        timerProgressBar: true,
                        background: '#0f172a',
                        color: '#e0e0e0',
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
                    // ❌ Error Toast (Dark Mode)
                    Swal.fire({
                        icon: 'error',
                        title: 'Update Failed',
                        text: data.message || 'Something went wrong while saving settings.',
                        background: '#1e1e2f',
                        color: '#f8d7da',
                        iconColor: '#f87171',
                        confirmButtonColor: '#e11d48',
                    });
                }
            })
            .catch(err => {
                console.error(err);
                Swal.fire({
                    icon: 'error',
                    title: 'Oops...',
                    text: 'Something went wrong. Please try again later.',
                    background: '#1e1e2f',
                    color: '#f8d7da',
                    iconColor: '#f87171',
                    confirmButtonColor: '#e11d48',
                });
            });
    });

});