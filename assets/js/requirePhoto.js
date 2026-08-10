// requirePhoto.js — toggle para sa "Student Photo Requirement"
//
// Kapag naka-ON, hindi maitatala ang attendance ng estudyanteng walang
// photo (tingnan ang crud/save_attendance.php). Malaki ang epekto nito
// kaya may kumpirmasyon muna bago buksan — hindi tulad ng ibang toggle
// dito na agad-agad.

const requirePhotoToggle = document.getElementById('require-photo-toggle');
const requirePhotoInput  = document.getElementById('require_photo_status');

if (requirePhotoToggle && requirePhotoInput) {

    requirePhotoToggle.addEventListener('change', async () => {
        const turningOn = requirePhotoToggle.checked;

        // Ang pagbukas ay maaaring humarang sa buong klase, kaya
        // tinatanong muna. Ang pagsara ay hindi mapanganib — dumaan
        // agad.
        if (turningOn) {
            // Diretso nang sa id — dating hinahalungkat nito ang DOM
            // pataas mula sa icon ng babala, na nasisira sa bawat
            // pagbabago ng balangkas ng page.
            const warning = document.getElementById('photoWarning')?.textContent?.trim();

            const result = await Swal.fire({
                icon: 'warning',
                title: 'Require student photo?',
                html: `<p>Students without an uploaded photo will <strong>not be able to
                       record attendance</strong>.</p>` +
                      (warning ? `<p class="text-warning" style="font-size:.9rem">${warning}</p>` : ''),
                showCancelButton: true,
                confirmButtonText: 'Yes, require it',
                cancelButtonText: 'Cancel',
                confirmButtonColor: '#dc3545',
                background: '#0f172a',
                color: '#e2e8f0'
            });

            if (!result.isConfirmed) {
                requirePhotoToggle.checked = false;   // ibalik
                return;
            }
        }

        const newStatus = turningOn ? '1' : '0';
        requirePhotoInput.value = newStatus;

        try {
            const res = await fetch(window.location.href, {
                method:  'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body:    'require_photo_status=' + encodeURIComponent(newStatus)
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.error || 'Update failed');

            Swal.fire({
                icon: 'success',
                title: newStatus === '1' ? 'Photo now required' : 'Photo now optional',
                toast: true,
                position: 'top-end',
                showConfirmButton: false,
                timer: 2000,
                background: '#0f172a',
                color: '#e2e8f0'
            });

            // I-refresh para tumugma ang status text at ang bilang ng
            // maaapektuhang estudyante sa bagong halaga.
            setTimeout(() => window.location.reload(), 900);

        } catch (err) {
            Swal.fire({
                toast: true,
                position: 'top-end',
                icon: 'error',
                title: 'Failed to update!',
                text: err.message,
                showConfirmButton: false,
                timer: 2500,
                background: '#0f172a',
                color: '#e2e8f0'
            });
            requirePhotoToggle.checked = !requirePhotoToggle.checked;
            requirePhotoInput.value = requirePhotoToggle.checked ? '1' : '0';
        }
    });
}
