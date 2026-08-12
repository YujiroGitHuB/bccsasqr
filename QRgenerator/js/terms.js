// ============================================================
// Terms and Conditions gate for QR generation
//
// There are now two conditions before Generate opens:
//   1. the student number is verified (fetch_students.js)
//   2. "I agree to the Terms and Conditions" is checked
//
// fetch_students.js owns (1). Rather than split the logic across two
// files, its enable/disable is wrapped here — however many times it
// is called, the button will not open until the box is checked.
// ============================================================

(function () {
    const agree      = document.getElementById('agreeTerms');
    const modal      = document.getElementById('termsModal');
    const openBtn    = document.getElementById('openTerms');
    const acceptBtn  = document.getElementById('termsAccept');
    const closeBtns  = [document.getElementById('closeTerms'),
                        document.getElementById('termsClose2')];
    const studentNo  = document.getElementById('studentNo');

    if (!agree || !modal) return;

    let studentVerified = false;   // itinatakda ng wrapper sa ibaba

    /* ── Wrap fetch_students.js's gate ──────────────────────────────── */
    const realEnable  = window.enableGenerateButton;
    const realDisable = window.disableGenerateButton;

    // fetch_students.js must already be loaded before this (see the
    // order in QRcode.php). If it is not, doing nothing is better than
    // breaking the entire generator page.
    if (typeof realEnable !== 'function' || typeof realDisable !== 'function') {
        console.error('terms.js: fetch_students.js must be loaded first');
        return;
    }

    window.enableGenerateButton = function () {
        studentVerified = true;
        refresh();
    };

    window.disableGenerateButton = function () {
        studentVerified = false;
        realDisable();
    };

    function refresh() {
        if (studentVerified && agree.checked) {
            realEnable();
            return;
        }

        realDisable();

        // realDisable() always writes "Verify First". That is confusing
        // once the student has actually been verified and only the
        // checkbox is missing — say what is really needed.
        if (studentVerified && typeof window.setButtonText === 'function') {
            window.setButtonText('Agree First', 'Agree First');
        }
    }

    /* ── Modal ──────────────────────────────────────────────────────── */
    function openModal()  { modal.classList.add('show'); }
    function closeModal() { modal.classList.remove('show'); }

    openBtn?.addEventListener('click', openModal);
    closeBtns.forEach(b => b?.addEventListener('click', closeModal));

    // "I Agree" in the modal is the same as ticking the box.
    acceptBtn?.addEventListener('click', () => {
        agree.checked = true;
        closeModal();
        agree.dispatchEvent(new Event('change'));
    });

    modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal();     // tapikin sa labas
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('show')) closeModal();
    });

    /* ── Pagtanggap ─────────────────────────────────────────────────── */
    agree.addEventListener('change', () => {
        refresh();

        // Only recorded once we know who it is — the record is
        // meaningless without a student number.
        if (agree.checked && studentVerified) {
            recordAcceptance(studentNo?.value.trim());
        }
    });

    function recordAcceptance(no) {
        if (!no) return;

        fetch('../api/accept_terms.php', {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify({ student_no: no })
        })
        .then(r => r.json())
        .then(d => {
            if (!d.success) console.warn('Terms not recorded:', d.error);
        })
        // A failed log must not stop the student from getting their QR
        // — they did see it and press it.
        .catch(err => console.warn('Terms not recorded:', err.message));
    }

    // If the browser restored a checked box (back button), bring the
    // button in line with the real state right away.
    refresh();
})();
