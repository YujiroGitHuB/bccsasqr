// attendanceIntegrity.js — the two "who is holding the phone" controls
//
//   One Device, One Student   a toggle, same shape as requirePhoto.js
//   Selfie Spot Check         a percentage with its own Save button
//
// Turning the toggle OFF is the dangerous direction here, which is the
// reverse of requirePhoto.js: ON is the default and the protection, and
// switching it off reopens the hole this whole feature was built to
// close. So the confirmation is on the way out, not on the way in.

const toastBase = {
    toast: true,
    position: 'top-end',
    showConfirmButton: false,
    timer: 2200,
    background: '#0f172a',
    color: '#e2e8f0'
};

// ─── One Device, One Student ──────────────────────────────────────────────────
const deviceToggle = document.getElementById('device-binding-toggle');
const deviceInput  = document.getElementById('device_binding_status');

if (deviceToggle && deviceInput) {

    deviceToggle.addEventListener('change', async () => {
        const turningOn = deviceToggle.checked;

        if (!turningOn) {
            const result = await Swal.fire({
                icon: 'warning',
                title: 'Turn this off?',
                html: `<p>One phone will again be able to record attendance for
                       <strong>as many students as it likes</strong> — holding the link
                       and knowing a classmate's number becomes enough.</p>
                       <p style="font-size:.9rem">Submissions are still logged, so you can
                       review them afterwards under Attendance &rsaquo; Integrity.</p>`,
                showCancelButton: true,
                confirmButtonText: 'Yes, turn it off',
                cancelButtonText: 'Keep it on',
                confirmButtonColor: '#dc3545',
                background: '#0f172a',
                color: '#e2e8f0'
            });

            if (!result.isConfirmed) {
                deviceToggle.checked = true;   // ibalik
                return;
            }
        }

        const newStatus = turningOn ? '1' : '0';
        deviceInput.value = newStatus;

        try {
            const res = await fetch(window.location.href, {
                method:  'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body:    'device_binding_status=' + encodeURIComponent(newStatus)
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.error || 'Update failed');

            Swal.fire({
                ...toastBase,
                icon: 'success',
                title: newStatus === '1' ? 'One device, one student' : 'Device check is off'
            });

            // Refresh so the badge and the blocked-this-week count match
            // the new value — the same reason requirePhoto.js reloads.
            setTimeout(() => window.location.reload(), 900);

        } catch (err) {
            Swal.fire({ ...toastBase, icon: 'error', title: 'Failed to update!', text: err.message, timer: 2500 });
            deviceToggle.checked = !deviceToggle.checked;
            deviceInput.value = deviceToggle.checked ? '1' : '0';
        }
    });
}

// ─── Selfie Spot Check ────────────────────────────────────────────────────────
const selfieForm  = document.getElementById('selfieRateForm');
const selfieInput = document.getElementById('selfie_rate');

if (selfieForm && selfieInput) {

    selfieForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        // Ang input ay may min/max na, pero ang number field ay
        // matitipa pa rin ng kahit ano. Pinipilit dito at sa server —
        // dalawang beses, dahil ang isa sa dalawa ay palaging kayang
        // laktawan.
        const rate = Math.max(0, Math.min(100, parseInt(selfieInput.value, 10) || 0));
        selfieInput.value = rate;

        const btn = selfieForm.querySelector('button[type="submit"]');
        btn.disabled = true;

        try {
            const res = await fetch(window.location.href, {
                method:  'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body:    'selfie_rate=' + encodeURIComponent(rate)
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.error || 'Update failed');

            Swal.fire({
                ...toastBase,
                icon: 'success',
                title: rate === 0
                    ? 'Selfie check is off'
                    : 'Asking ' + rate + '% of submissions'
            });

            setTimeout(() => window.location.reload(), 900);

        } catch (err) {
            Swal.fire({ ...toastBase, icon: 'error', title: 'Failed to update!', text: err.message, timer: 2500 });
        } finally {
            btn.disabled = false;
        }
    });
}
