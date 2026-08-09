// ============================================================
//  Student Photo Profiles — AJAX paginated + searchable
//  Rows come from api/get_student_photos.php one page at a time,
//  so the browser never loads every student at once.
// ============================================================
const cnt   = document.getElementById('spCnt');
const tag   = document.getElementById('spTag');
const qEl   = document.getElementById('spQ');
const coEl  = document.getElementById('spCourse');
const secEl = document.getElementById('spSection');
const grid  = document.getElementById('spGrid');
const more  = document.getElementById('spMore');

const PER_PAGE = 30;
let filt = 'all';
let page = 1;
let totalPages = 1;
let total = 0;
let loading = false;

// ── Helpers ─────────────────────────────────────────────
function esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, m => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]
    ));
}

function initials(fullname) {
    const p = String(fullname || '').split(',');
    const a = (p[0] || '').trim()[0] || '';
    const b = (p[1] || '').trim()[0] || '';
    return (a + b).toUpperCase();
}

const EMPTY_HTML =
    '<div class="sp-empty"><i class="bi bi-person-slash"></i><p>No students match your search.</p></div>';

function cardHtml(s) {
    const has  = s.has_photo;
    const init = initials(s.fullname);
    const nm   = esc(s.fullname);
    let inner  = '';

    if (has) {
        const url = '../' + esc(s.photo_path);
        // Delete is admin-only; instructors get a read-only (view + zoom) card.
        if (window.SP_IS_ADMIN) {
            inner += `<button class="sp-x" data-id="${s.id}" data-name="${nm}"><i class="bi bi-x-lg"></i></button>`;
        }
        inner += `<div class="sp-av-wrap"><img src="${url}" alt="${nm}" loading="lazy" decoding="async" style="cursor:zoom-in"` +
                 ` onerror="this.outerHTML='<div class=\\'sp-av-init\\'>${init}</div>'"></div>`;
    } else {
        inner += `<div class="sp-av-wrap"><div class="sp-av-init">${init}</div></div>`;
    }

    inner += `<div class="sp-n">${nm}</div>`;
    inner += `<div class="sp-sn">${esc(s.student_no)}</div>`;
    inner += `<div class="sp-c">${esc(s.course)} &middot; ${esc(s.section)}</div>`;

    if (has) {
        inner += `<span class="sp-badge ok"><i class="bi bi-check-circle-fill"></i> Uploaded</span>`;
        if (s.updated_label) {
            inner += `<div class="sp-dt"><i class="bi bi-clock"></i> ${esc(s.updated_label)}</div>`;
        }
    } else {
        inner += `<span class="sp-badge no"><i class="bi bi-exclamation-circle-fill"></i> No Photo</span>`;
    }

    return `<div class="sp-card ${has ? '' : 'nc'}" id="card-${s.id}" data-photo="${has ? 1 : 0}">${inner}</div>`;
}

// ── Fetch a page ────────────────────────────────────────
async function load(reset) {
    if (loading) return;
    loading = true;
    if (reset) page = 1;

    more.disabled = true;

    const params = new URLSearchParams({
        q: qEl.value.trim(),
        course: coEl.value,
        section: secEl.value,
        filter: filt,
        page: page,
        per_page: PER_PAGE
    });

    try {
        const r = await fetch('../api/get_student_photos.php?' + params.toString());
        const d = await r.json();

        if (!d.success) {
            if (reset) grid.innerHTML = EMPTY_HTML;
            more.style.display = 'none';
            return;
        }

        total = d.total;
        totalPages = d.total_pages;

        if (reset) grid.innerHTML = '';
        const em = grid.querySelector('.sp-empty');
        if (em) em.remove();

        grid.insertAdjacentHTML('beforeend', d.students.map(cardHtml).join(''));

        cnt.textContent = total;
        tag.innerHTML = filt !== 'all'
            ? `<span class="sp-tag"><i class="bi bi-funnel-fill"></i> ${filt === 'with' ? 'With Photo' : 'No Photo'}</span>`
            : '';

        if (total === 0) grid.innerHTML = EMPTY_HTML;

        more.style.display = page < totalPages ? '' : 'none';
    } catch {
        if (reset) grid.innerHTML = EMPTY_HTML;
        more.style.display = 'none';
    } finally {
        loading = false;
        more.disabled = false;
    }
}

// ── Search / filters (server-side) ──────────────────────
let debounce;
qEl.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => load(true), 300);
});
coEl.addEventListener('change', () => load(true));
secEl.addEventListener('change', () => load(true));

document.querySelectorAll('.sp-pill').forEach(p => {
    p.addEventListener('click', () => {
        document.querySelectorAll('.sp-pill').forEach(x => x.classList.remove('on'));
        p.classList.add('on');
        filt = p.dataset.f;
        load(true);
    });
});

more.addEventListener('click', () => {
    if (page < totalPages) {
        page++;
        load(false);
    }
});

// ── Initial load (with skeleton → content transition) ───
window.addEventListener('DOMContentLoaded', async () => {
    await load(true);
    grid.classList.add('loaded');
    const sk = document.getElementById('skGrid');
    if (sk) {
        sk.classList.add('hidden');
        setTimeout(() => sk.remove(), 280);
    }
});

// ── Delete ──────────────────────────────────────────────
let pid = null;
const modal = new bootstrap.Modal(document.getElementById('spDelModal'));

function askDelete(id, name) {
    pid = id;
    document.getElementById('spDelMsg').textContent =
        `Remove photo for "${name}"? They can re-upload anytime.`;
    modal.show();
}

// Cards are rendered dynamically — use event delegation for delete + zoom.
grid.addEventListener('click', e => {
    const x = e.target.closest('.sp-x');
    if (x) { askDelete(x.dataset.id, x.dataset.name); return; }

    const img = e.target.closest('.sp-av-wrap img');
    if (img) openLightbox(img.src, img.alt);
});

document.getElementById('spDelOk').addEventListener('click', async function () {
    if (!pid) return;
    const btn = this;
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
    try {
        const r = await fetch('../api/delete_student_photo.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ student_id: pid })
        });
        const d = await r.json();
        if (d.success) {
            const card = document.getElementById('card-' + pid);
            if (card) {
                card.style.transition = 'opacity .22s, transform .22s';
                card.style.opacity = '0';
                card.style.transform = 'scale(.88)';
                setTimeout(() => {
                    card.remove();
                    total = Math.max(0, total - 1);
                    cnt.textContent = total;
                    if (total === 0) grid.innerHTML = EMPTY_HTML;
                }, 240);
            }
            modal.hide();
        } else {
            alert(d.message || 'Failed.');
        }
    } catch { alert('Network error.'); }
    finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="bi bi-trash3"></i> Remove';
        pid = null;
    }
});

// ── Photo lightbox (click a photo to zoom in) ───────────
(function () {
    const style = document.createElement('style');
    style.textContent = `
#spLightbox{position:fixed;inset:0;z-index:20000;display:none;align-items:center;justify-content:center;padding:24px;background:rgba(4,8,16,.9);backdrop-filter:blur(4px);cursor:zoom-out}
#spLightbox.show{display:flex}
#spLightbox .sp-lb-fig{margin:0;text-align:center;max-width:92vw;animation:spLbIn .18s ease}
#spLightbox img{max-width:92vw;max-height:82vh;border-radius:14px;box-shadow:0 24px 70px rgba(0,0,0,.6);cursor:default;object-fit:contain}
#spLightbox figcaption{margin-top:14px;color:#e2e8f0;font-family:'Syne',sans-serif;font-weight:600;font-size:1rem;letter-spacing:-.01em}
#spLightbox .sp-lb-close{position:absolute;top:18px;right:22px;width:44px;height:44px;border:none;border-radius:50%;background:rgba(255,255,255,.1);color:#fff;font-size:1.8rem;line-height:1;cursor:pointer;transition:background .18s}
#spLightbox .sp-lb-close:hover{background:rgba(255,255,255,.22)}
@keyframes spLbIn{from{opacity:0;transform:scale(.94)}to{opacity:1;transform:scale(1)}}
`;
    document.head.appendChild(style);

    const lb = document.createElement('div');
    lb.id = 'spLightbox';
    lb.innerHTML =
        '<button type="button" class="sp-lb-close" aria-label="Close">&times;</button>' +
        '<figure class="sp-lb-fig"><img alt=""><figcaption></figcaption></figure>';
    document.body.appendChild(lb);

    const lbImg = lb.querySelector('img');
    const lbCap = lb.querySelector('figcaption');

    window.openLightbox = function (src, name) {
        lbImg.src = src;
        lbImg.alt = name || '';
        lbCap.textContent = name || '';
        lb.classList.add('show');
        document.body.style.overflow = 'hidden';
    };

    function close() {
        lb.classList.remove('show');
        lbImg.src = '';
        document.body.style.overflow = '';
    }

    // Click anywhere except the image itself closes the lightbox.
    lb.addEventListener('click', e => { if (e.target !== lbImg) close(); });
    document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && lb.classList.contains('show')) close();
    });
})();
