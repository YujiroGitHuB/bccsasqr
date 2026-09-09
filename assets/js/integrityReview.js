// integrityReview.js — "tiningnan ko na ito"
//
// Ang bawat flagged na hilera ay nagtatapos sa isang tanong na tao
// lamang ang makakasagot: hiniram ba talaga ang telepono? Ang sagot
// na iyon ay nawawala kapag walang paglalagyan, at ang parehong anim
// na hilera ay muling sinusuri kada linggo.
//
// Hindi nagre-reload ang pahina pagkatapos: ang gurong dumaraan sa
// sampung hilera ay mawawala ang kinalalagyan niya sa listahan kada
// pindot, at ang salaang pinili niya ay muling bubuuin sa bawat
// pagkakataon. Ang cell lamang ang muling iginuguhit.

const revToast = {
    toast: true,
    position: 'top-end',
    showConfirmButton: false,
    timer: 2000,
    background: '#0f172a',
    color: '#e2e8f0'
};

/** Ang laman ng cell para sa isang kalagayan. */
function revRender(td, state) {
    const id = td.dataset.id;

    if (!state.reviewed) {
        td.innerHTML = `<button type="button" class="ati-rev" data-act="do" data-id="${id}">
                            <i class="bi bi-check2"></i> Review
                        </button>`;
        return;
    }

    // textContent para sa tala: isinusulat ito ng tao sa isang input,
    // at ang pahinang ito ay may hawak ng student number at IP.
    const wrap = document.createElement('div');
    wrap.className = 'ati-rev-done';

    const mark = document.createElement('span');
    mark.className = 'ati-rev-mark';
    mark.innerHTML = '<i class="bi bi-check-circle-fill"></i>';
    mark.append(state.at || 'Reviewed');
    if (state.by) mark.title = 'Reviewed by ' + state.by;
    wrap.appendChild(mark);

    if (state.note) {
        const note = document.createElement('span');
        note.className = 'ati-rev-note';
        note.textContent = state.note;
        wrap.appendChild(note);
    }

    const undo = document.createElement('button');
    undo.type = 'button';
    undo.className = 'ati-rev-undo';
    undo.dataset.act = 'undo';
    undo.dataset.id = id;
    undo.textContent = 'Undo';
    wrap.appendChild(undo);

    td.innerHTML = '';
    td.appendChild(wrap);
}

async function revPost(id, body) {
    const res = await fetch('../crud/review_audit.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body
    });

    const data = await res.json();
    if (!data.success) throw new Error(data.message || 'Update failed');
    return data;
}

// Isang listener sa talahanayan at hindi isa kada hilera: ang
// listahan ay ipinapakita nang tig-lilimampu, at ang cell ay muling
// iginuguhit pagkatapos ng bawat pindot.
document.addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-act="do"], [data-act="undo"]');
    if (!btn) return;

    const td = btn.closest('.ati-review');
    if (!td) return;

    const id = btn.dataset.id;

    if (btn.dataset.act === 'undo') {
        const ask = await Swal.fire({
            icon: 'question',
            title: 'Mark as not reviewed?',
            text: 'The note on this row will be removed.',
            showCancelButton: true,
            confirmButtonText: 'Yes, undo',
            cancelButtonText: 'Keep it',
            confirmButtonColor: '#8b5cf6',
            background: '#0f172a',
            color: '#e2e8f0'
        });
        if (!ask.isConfirmed) return;

        try {
            await revPost(id, 'id=' + encodeURIComponent(id) + '&undo=1');
            revRender(td, { reviewed: false });
            Swal.fire({ ...revToast, icon: 'success', title: 'Back to unreviewed' });
        } catch (err) {
            Swal.fire({ ...revToast, icon: 'error', title: 'Failed', text: err.message, timer: 3000 });
        }
        return;
    }

    const ask = await Swal.fire({
        icon: 'info',
        title: 'What did you find?',
        input: 'text',
        inputPlaceholder: 'Borrowed phone, confirmed with the student',
        inputAttributes: { maxlength: 255 },
        html: `<p style="font-size:.88rem;margin:0">
                   The note is what the next person reads &mdash; and the reason
                   you will not have to look at this row again.
               </p>`,
        showCancelButton: true,
        confirmButtonText: 'Mark reviewed',
        cancelButtonText: 'Cancel',
        confirmButtonColor: '#8b5cf6',
        background: '#0f172a',
        color: '#e2e8f0'
    });

    // Ang blangkong tala ay pinapayagan: ang "tiningnan ko na ito at
    // walang dapat ipag-alala" ay isang sagot, at ang pilitin ang
    // guro na mag-type ng isang bagay ay pagpilit sa kanya na
    // mag-type ng kahit ano.
    if (!ask.isConfirmed) return;

    const note = ask.value || '';

    try {
        const data = await revPost(id, 'id=' + encodeURIComponent(id) + '&note=' + encodeURIComponent(note));
        revRender(td, { reviewed: true, note: data.note, by: data.by, at: data.at });
        Swal.fire({ ...revToast, icon: 'success', title: 'Marked reviewed' });
    } catch (err) {
        Swal.fire({ ...revToast, icon: 'error', title: 'Failed', text: err.message, timer: 3000 });
    }
});
