// ============================================================
// Terms and Conditions gate para sa QR generation
//
// Dalawa na ngayon ang kondisyon bago mabuksan ang Generate:
//   1. na-verify ang student number (fetch_students.js)
//   2. naka-check ang "I agree to the Terms and Conditions"
//
// Ang fetch_students.js ang may hawak ng (1). Para hindi na natin
// hatiin ang lohika sa dalawang file, binabalot natin dito ang
// enable/disable nito — kahit ilang beses itong tawagin, hindi
// bubukas ang button hangga't hindi pa naka-check ang kahon.
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

    /* ── Balutin ang gate ng fetch_students.js ──────────────────────── */
    const realEnable  = window.enableGenerateButton;
    const realDisable = window.disableGenerateButton;

    // Dapat nakakarga na ang fetch_students.js bago ito (tingnan ang
    // pagkakasunod sa QRcode.php). Kung hindi, mas mabuting huwag nang
    // gumalaw kaysa sirain ang buong pahina ng generator.
    if (typeof realEnable !== 'function' || typeof realDisable !== 'function') {
        console.error('terms.js: dapat nakakarga muna ang fetch_students.js');
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

        // Ang realDisable() ay laging naglalagay ng "Verify First".
        // Nakalilito iyon kapag na-verify na pala ang estudyante at
        // ang kahon na lang pala ang kulang — sabihin natin kung ano
        // talaga ang kailangang gawin.
        if (studentVerified && typeof window.setButtonText === 'function') {
            window.setButtonText('Agree First', 'Agree First');
        }
    }

    /* ── Modal ──────────────────────────────────────────────────────── */
    function openModal()  { modal.classList.add('show'); }
    function closeModal() { modal.classList.remove('show'); }

    openBtn?.addEventListener('click', openModal);
    closeBtns.forEach(b => b?.addEventListener('click', closeModal));

    // Ang "I Agree" sa modal ay pareho ng pag-check sa kahon.
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

        // Itinatala lang kapag alam natin kung sino — walang saysay
        // ang talaan nang walang student number.
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
        // Ang hindi pagkatala ay hindi dapat humadlang sa estudyante
        // na makakuha ng QR — nakita at pinindot naman niya ito.
        .catch(err => console.warn('Terms not recorded:', err.message));
    }

    // Kung na-restore ng browser ang naka-check na kahon (back button),
    // itugma agad ang button sa totoong estado.
    refresh();
})();
