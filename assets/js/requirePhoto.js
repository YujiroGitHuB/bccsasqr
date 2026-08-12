// requirePhoto.js — the "Student Photo Requirement" toggle
//
// When ON, attendance cannot be recorded for a student with no photo
// (see crud/save_attendance.php). The effect is large, so turning it
// on asks for confirmation first — unlike the other toggles here,
// which act immediately.

const requirePhotoToggle = document.getElementById('require-photo-toggle');
const requirePhotoInput  = document.getElementById('require_photo_status');

if (requirePhotoToggle && requirePhotoInput) {

    requirePhotoToggle.addEventListener('change', async () => {
        const turningOn = requirePhotoToggle.checked;

        // Turning it on can block a whole class, so it asks first.
        // Turning it off is not dangerous — let it through.
        if (turningOn) {
            // Straight to the id now — this used to walk up the DOM
            // from the warning icon, which broke on every change to
            // the page structure.
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

            // Refresh so the status text and the count of affected
            // students match the new value.
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
