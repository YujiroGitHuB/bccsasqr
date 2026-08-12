// ─── generate_link.js ─────────────────────────────────────────────────────────

let allLinks = [];

// ─── Boot ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    fetchLinks(true); // always fetch fresh — triggers auto-deactivation on backend
    document.getElementById('searchInput').addEventListener('input', applyFilters);
    document.getElementById('filterSection').addEventListener('change', applyFilters);
    document.getElementById('filterOwner').addEventListener('change', applyFilters);
});

// ─── Fetch links via AJAX ─────────────────────────────────────────────────────
function fetchLinks(forceRefresh = false) {
    const url = 'get_links_ajax.php' + (forceRefresh ? '?refresh=1' : '');

    fetch(url)
        .then(r => {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        })
        .then(res => {
            if (!res.success) throw new Error(res.message || 'Server error');
            allLinks = res.data;
            renderCards(allLinks);
            populateSectionFilter(allLinks);
        })
        .catch(err => {
            console.error('Failed to load links:', err);
            document.getElementById('skeletonLoader').innerHTML = `
                <div class="col-12 text-center py-5">
                    <i class="bi bi-wifi-off fs-1 text-danger mb-3 d-block"></i>
                    <p class="text-muted mb-0">Failed to load attendance links.</p>
                    <a href="#" class="btn btn-sm btn-outline-primary mt-3" onclick="fetchLinks(true); return false;">
                        <i class="bi bi-arrow-clockwise me-1"></i>Try again
                    </a>
                </div>`;
        });
}

// ─── Render all cards ─────────────────────────────────────────────────────────
function renderCards(links) {
    const skeleton   = document.getElementById('skeletonLoader');
    const container  = document.getElementById('cardsContainer');
    const emptyState = document.getElementById('emptyState');

    skeleton.style.display = 'none';

    if (!links || links.length === 0) {
        container.style.setProperty('display', 'none', 'important');
        emptyState.style.display = 'block';
        updateCount(0, 0);
        return;
    }

    container.innerHTML = links.map(l => buildCard(l)).join('');
    container.style.setProperty('display', 'flex', 'important');
    container.className = 'row g-3';
    emptyState.style.display = 'none';

    updateCount(links.length, links.length);
}

// ─── Build a single card HTML string ──────────────────────────────────────────
function buildCard(l) {
    const subject    = l.subject;
    const short_code = l.short_code;
    const link       = l.link;
    const is_mine    = subject.is_mine == 1;
    const uid        = 'link-' + short_code;

    const mineBadge = is_mine ? '<span class="badge bg-success">Mine</span>' : '';
    const mineClass = is_mine ? 'my-subject' : '';

    return `
        <div class="col-xl-4 col-md-6 card-item"
            data-search="${escHtml((subject.subject_name + ' ' + subject.subject_code + ' ' + subject.section + ' ' + subject.instructor_name).toLowerCase())}"
            data-section="${escHtml(subject.section)}"
            data-mine="${is_mine ? 'mine' : 'others'}">

            <div class="link-card card h-100 ${mineClass}">
                <div class="card-body d-flex flex-column gap-3">

                    <div class="d-flex align-items-start justify-content-between gap-2 flex-wrap">
                        <div class="d-flex align-items-center gap-2 flex-wrap">
                            <span class="badge bg-secondary">${escHtml(subject.section)}</span>
                            <span class="fw-bold">${escHtml(subject.subject_code)}</span>
                            ${mineBadge}
                        </div>
                        <span class="short-code-pill">${short_code}</span>
                    </div>

                    <div>
                        <div class="fw-semibold">${escHtml(subject.subject_name)}</div>
                        <span class="instructor-badge mt-1 d-inline-block text-muted">
                            <i class="bi bi-person-fill me-1"></i>${escHtml(subject.instructor_name)}
                        </span>
                    </div>

                    <div class="link-display" id="${uid}">${wbrUrl(link)}</div>

                    <div class="d-flex flex-wrap gap-2 mt-auto">
                        <button class="btn btn-sm btn-primary" onclick="copyLink('${uid}', this)">
                            <i class="bi bi-clipboard me-1"></i>Copy
                        </button>
                        <a href="${escHtml(link)}" class="btn btn-sm btn-outline-success" target="_blank">
                            <i class="bi bi-box-arrow-up-right me-1"></i>Test
                        </a>
                        <button class="btn btn-sm btn-outline-info" onclick="generateQR(
                            '${escQ(link)}',
                            '${escQ(subject.section)}',
                            '${escQ(subject.subject_code)}',
                            '${escQ(subject.subject_name)}'
                        )">
                            <i class="bi bi-qr-code me-1"></i>QR
                        </button>
                        <button class="btn btn-sm btn-outline-danger ms-auto" onclick="deactivateLink('${short_code}', this)">
                            <i class="bi bi-trash"></i>
                        </button>
                    </div>

                </div>
            </div>
        </div>
    `;
}

// ─── Populate section dropdown ────────────────────────────────────────────────
function populateSectionFilter(links) {
    const select = document.getElementById('filterSection');
    const seen   = new Set();
    links.forEach(l => {
        const sec = l.subject.section;
        if (!seen.has(sec)) {
            seen.add(sec);
            const opt       = document.createElement('option');
            opt.value       = sec;
            opt.textContent = sec;
            select.appendChild(opt);
        }
    });
}

// ─── Search & filter ──────────────────────────────────────────────────────────
function applyFilters() {
    const search  = document.getElementById('searchInput').value.toLowerCase().trim();
    const section = document.getElementById('filterSection').value;
    const owner   = document.getElementById('filterOwner').value;

    const items = document.querySelectorAll('#cardsContainer .card-item');
    let visible = 0;

    items.forEach(el => {
        const matchSearch  = !search  || el.dataset.search.includes(search);
        const matchSection = !section || el.dataset.section === section;
        const matchOwner   = !owner   || el.dataset.mine === owner;

        const show = matchSearch && matchSection && matchOwner;
        el.style.display = show ? '' : 'none';
        if (show) visible++;
    });

    updateCount(visible, allLinks.length);
    document.getElementById('noResults').style.display =
        (visible === 0 && allLinks.length > 0) ? 'block' : 'none';
}

function updateCount(visible, total) {
    document.getElementById('visibleCount').textContent = visible;
    document.getElementById('totalCount').textContent   = total;
}

// ─── Copy link ────────────────────────────────────────────────────────────────
function copyLink(uid, btn) {
    // textContent, not innerText: it is unaffected by layout, so soft
    // line breaks cannot slip into the copied text.
    const text = document.getElementById(uid)?.textContent.trim();
    if (!text) return;
    navigator.clipboard.writeText(text).then(() => {
        const original = btn.innerHTML;
        btn.innerHTML  = '<i class="bi bi-check2 me-1"></i>Copied!';
        btn.classList.replace('btn-primary', 'btn-success');
        setTimeout(() => {
            btn.innerHTML = original;
            btn.classList.replace('btn-success', 'btn-primary');
        }, 2000);
    });
}

// ─── Deactivate link ──────────────────────────────────────────────────────────
function deactivateLink(short_code, btn) {
    Swal.fire({
        title: 'Deactivate Link?',
        text: 'Students will no longer be able to use this attendance link.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#dc3545',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Yes, deactivate',
        cancelButtonText: 'Cancel',
        background: '#0d1117',
        color: '#dee2e6',
    }).then(result => {
        if (!result.isConfirmed) return;

        btn.disabled  = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';

        fetch('../crud/deactivate_link.php', {
            method : 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body   : 'short_code=' + encodeURIComponent(short_code),
        })
        .then(r => r.json())
        .then(res => {
            if (res.success) {
                allLinks = allLinks.filter(l => l.short_code !== short_code);
                fetch('get_links_ajax.php?refresh=1').catch(() => {});

                const card = btn.closest('.card-item');
                card.style.transition = 'opacity .3s';
                card.style.opacity    = '0';
                setTimeout(() => {
                    card.remove();
                    // Re-fetch so new generated link appears without full page reload
                    fetchLinks(true);
                }, 300);

                Swal.fire({
                    title: 'Deactivated!',
                    text: 'Attendance link has been deactivated.',
                    icon: 'success',
                    timer: 1800,
                    showConfirmButton: false,
                    background: '#0d1117',
                    color: '#dee2e6',
                });
            } else {
                Swal.fire({
                    title: 'Error',
                    text: res.message || 'Failed to deactivate link.',
                    icon: 'error',
                    background: '#0d1117',
                    color: '#dee2e6',
                });
                btn.disabled  = false;
                btn.innerHTML = '<i class="bi bi-trash"></i>';
            }
        })
        .catch(() => {
            Swal.fire({
                title: 'Network Error',
                text: 'Please check your connection and try again.',
                icon: 'error',
                background: '#0d1117',
                color: '#dee2e6',
            });
            btn.disabled  = false;
            btn.innerHTML = '<i class="bi bi-trash"></i>';
        });
    });
}

// ─── QR Code ──────────────────────────────────────────────────────────────────
let qrInstance = null;

function generateQR(link, section, code, name) {
    document.getElementById('qrSubjectName').textContent     = section;
    document.getElementById('qrSubjectCode').textContent     = code;
    document.getElementById('qrSubjectFullName').textContent = name;

    const container     = document.getElementById('qrcode');
    container.innerHTML = '';

    // Black on white — this is not decoration, a camera measures it.
    //
    // Previously: cyan (#00c8ff) modules on dark navy (#0a1628). Two
    // problems with that: the contrast between the two colors is low,
    // and the polarity is INVERTED — the QR spec expects dark modules
    // on a light background. Some scanners can read an inverted code,
    // many cannot. It also carried into the downloaded PNG that gets
    // posted on a wall or projected.
    qrInstance = new QRCode(container, {
        text        : link,
        width       : 220,
        height      : 220,
        colorDark   : '#000000',
        colorLight  : '#ffffff',
        correctLevel: QRCode.CorrectLevel.H,
    });

    new bootstrap.Modal(document.getElementById('qrModal')).show();
}

function downloadQR() {
    const canvas = document.querySelector('#qrcode canvas');
    if (!canvas) return;
    const a    = document.createElement('a');
    a.href     = canvas.toDataURL('image/png');
    a.download = 'attendance-qr.png';
    a.click();
}

// ─── Escape helpers ───────────────────────────────────────────────────────────
// A URL is one long "word" with no spaces, so the browser breaks it
// anywhere — mid-way through "daily_attendance" on a phone. <wbr>
// marks the allowed break points: after / ? = & so it breaks at a path
// or parameter boundary.
//
// <wbr> adds no text, so what gets copied is still intact.
function wbrUrl(str) {
    return escHtml(str).replace(/(&amp;|[\/?=])/g, '$1<wbr>');
}

function escHtml(str) {
    return String(str ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}
function escQ(str) {
    return String(str ?? '').replace(/'/g, "\\'").replace(/"/g, '&quot;');
}