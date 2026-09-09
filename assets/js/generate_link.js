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
            announceRotated(res.rotated);
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

                    ${buildExpiry(l)}

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
                        <button class="btn btn-sm ${l.room_code ? 'btn-warning' : 'btn-outline-warning'}"
                            title="${l.room_code ? 'Students must type the code on the board' : 'Show a rotating code students must type'}"
                            onclick="openRoomCode(
                                '${short_code}',
                                '${escQ(subject.subject_code + ' · ' + subject.section)}',
                                ${l.room_code ? 'true' : 'false'}
                            )">
                            <i class="bi bi-display me-1"></i>Code
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

/**
 * Sinasabi kung ilang link ang binigyan ng bagong code habang wala
 * ka — ang mga nag-expire noong nakaraang araw, pinalitan ng
 * pages/get_links_ajax.php sa pagbukas ng pahinang ito.
 *
 * Kailangang sabihin: kung tahimik itong nangyari, ipadadala mo ang
 * lumang URL na nasa kopya mo at magtataka ka kung bakit walang
 * nakakapag-scan.
 */
function announceRotated(rotated) {
    if (!rotated || !rotated.length) return;

    const n = rotated.length;

    Swal.fire({
        icon : 'info',
        title: n === 1 ? 'One link was renewed' : n + ' links were renewed',
        html : `They expired on an earlier day, so they were given fresh codes.<br>
                <span style="font-size:.9em;opacity:.75">
                    The old URLs no longer work — copy the new ones before sending.
                </span>`,
        confirmButtonColor: '#8b5cf6'
    });
}

// ─── Expiry ───────────────────────────────────────────────────────────────────
//
// Ang buong estado ay galing sa server (tingnan ang
// attach_link_expiry sa pages/get_links_ajax.php): ang expires_in ay
// sinukat ng orasan ng database. Ang browser ay nagbibilang lamang
// pababa mula sa bilang na iyon, kaya walang naipapasok na maling
// oras ang telepono.
//
// Ang na-expire na link ay HINDI nawawala. Nananatili itong nakikita
// na may "Expired" na tatak at may Extend, dahil ang unang tanong
// pagkatapos ng isang klase ay "nakuha ba ang atendans?" at hindi
// "nasaan ang link ko?".

const EXPIRY_PRESETS = [
    { label: '1h', minutes: 60 },
    { label: '2h', minutes: 120 },
    { label: '4h', minutes: 240 },
    { label: 'End of day', preset: 'eod' }
];

function humanLeft(seconds) {
    if (seconds <= 0) return 'closed';

    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);

    // Naka-pad ang segundo (at ang minuto kapag may oras) para hindi
    // tumatalon ang lapad ng teksto kada tiktok — kasama ang
    // tabular-nums sa CSS, nananatiling nakatigil ang bilang.
    const pad = n => String(n).padStart(2, '0');

    // Sa antas ng araw, ingay na ang segundo — walang nagbabantay ng
    // link na may dalawang araw pang natitira.
    if (d > 0) return d + 'd ' + h + 'h ' + pad(m) + 'm';
    if (h > 0) return h + 'h ' + pad(m) + 'm ' + pad(s) + 's';
    if (m > 0) return m + 'm ' + pad(s) + 's';
    return s + 's';
}

function buildExpiry(l) {
    const code = l.short_code;
    const uid  = 'exp-' + code;

    // Ang eksaktong petsa ay lumabas sa pill at naging sariling linya
    // sa ibaba. Sa loob ng pill, dalawang bagay ang laman nito — ang
    // bilang pababa at ang "Aug 15, 2026 11:59 PM" — at sa lapad ng
    // isang card ay itinutulak niyon ang Change sa sarili nitong linya,
    // kung saan mukha itong naiwan. Ang pill ang mabilis basahin; ang
    // petsa ay ang sagot sa "anong oras ba talaga", at hindi
    // kailangang nasa loob ng parehong hugis.
    let status, when = '';

    if (l.is_expired) {
        status = `<span class="lnk-exp-badge is-over"><i class="bi bi-slash-circle"></i> Expired</span>`;
        when   = l.expires_label ? `Closed ${escHtml(l.expires_label)}` : '';
    } else if (l.expires_in !== null && l.expires_in !== undefined) {
        const soon = l.expires_in <= 900 ? ' is-soon' : '';
        status = `<span class="lnk-exp-badge${soon}" data-countdown="${l.expires_in}">
                      <i class="bi bi-hourglass-split"></i>
                      Closes in <b class="lnk-exp-clock">${humanLeft(l.expires_in)}</b>
                  </span>`;
        when   = escHtml(l.expires_label || '');
    } else {
        status = `<span class="lnk-exp-badge is-none"><i class="bi bi-infinity"></i> No expiry</span>`;
    }

    const presets = EXPIRY_PRESETS.map(p => {
        const arg = p.preset ? `{preset:'${p.preset}'}` : `{minutes:${p.minutes}}`;
        return `<button type="button" class="lnk-exp-preset"
                    onclick="setExpiry('${code}', ${arg}, this)">${p.label}</button>`;
    }).join('');

    // Ang na-expire na link ay may DALAWANG sagot, at magkaiba sila:
    //
    //   Extend   — kaparehong klase, natagalan lang. Kailangang
    //              manatili ang code: 'yon ang hawak ng mga estudyante
    //              na nasa harap mo ngayon.
    //   New link — bagong session. Dapat mamatay ang lumang URL, dahil
    //              nasa group chat na 'yon at may screenshot na.
    //
    // "New link" ang pangunahin dahil 'yon ang mas madalas: mas
    // marami ang susunod na klase kaysa sa lumagpas sa oras.
    const actions = l.is_expired
        ? `<button type="button" class="lnk-exp-new" onclick="newLinkCode('${code}', this)">
               <i class="bi bi-arrow-repeat"></i> New link
           </button>
           <button type="button" class="lnk-exp-toggle" onclick="extendExpiry('${uid}', ${l.expires_in || 0})">
               <i class="bi bi-clock-history"></i> Extend
           </button>`
        : `<button type="button" class="lnk-exp-toggle" onclick="toggleExpiry('${uid}')">
               <i class="bi bi-clock-history"></i>
               ${l.expires_at ? 'Change' : 'Set expiry'}
           </button>`;

    return `
        <div class="lnk-exp" id="${uid}">
            <div class="lnk-exp-row">
                ${status}
                <span class="lnk-exp-actions">${actions}</span>
            </div>
            ${when ? `<div class="lnk-exp-when">${when}</div>` : ''}

            <div class="lnk-exp-panel" hidden>
                <div class="lnk-exp-presets">${presets}</div>
                <div class="lnk-exp-custom">
                    <input type="datetime-local" class="lnk-exp-at" aria-label="Custom expiry date and time">
                    <button type="button" class="lnk-exp-set"
                        onclick="setExpiry('${code}', {at: this.previousElementSibling.value}, this)">Set</button>
                </div>
                ${l.expires_at ? `<button type="button" class="lnk-exp-clear"
                        onclick="setExpiry('${code}', {clear: 1}, this)">Remove expiry</button>` : ''}
            </div>
        </div>`;
}

function toggleExpiry(uid) {
    const panel = document.getElementById(uid)?.querySelector('.lnk-exp-panel');
    if (panel) panel.hidden = !panel.hidden;
}

/**
 * Extend, na may tanong kung matagal nang sarado ang link.
 *
 * Ang link na nag-expire dalawang oras na ang nakalipas ay malamang
 * hindi na ang klaseng nasa harap mo — at ang pagpapalawig nito ay
 * muling nagbubukas ng URL na ipinamigay mo na. Ang nag-expire lang
 * kanina-kanina ay walang tanong: 'yon ang totoong "natagalan ang
 * klase".
 *
 * Ang lampas-isang-araw ay hindi na umaabot dito — binigyan na 'yon
 * ng bagong code ng pages/get_links_ajax.php bago pa maipakita.
 */
function extendExpiry(uid, expiresIn) {
    const overFor = Math.abs(expiresIn || 0);   // negatibo ang expires_in kapag lumipas na

    if (overFor < 7200) {
        toggleExpiry(uid);
        return;
    }

    const hours = Math.round(overFor / 3600);

    Swal.fire({
        icon : 'question',
        title: 'Extend this same link?',
        html : `Closed about <b>${hours} hour${hours === 1 ? '' : 's'}</b> ago.<br>
                <span style="font-size:.9em;opacity:.75">
                    Anyone who already has this URL — group chat, screenshot — can use it again.
                    For a new class, choose <b>New link</b> instead.
                </span>`,
        showCancelButton : true,
        confirmButtonText: 'Yes, extend the same link',
        cancelButtonText : 'Cancel',
        confirmButtonColor: '#8b5cf6'
    }).then(r => {
        if (r.isConfirmed) toggleExpiry(uid);
    });
}

/**
 * Bagong short_code para sa parehong klase. Walang expiry ang bagong
 * link, kaya kusang bumubukas ang panel — ang susunod na hakbang ay
 * ang pagtatakda ng oras, bago mo pa ito ipadala.
 */
function newLinkCode(short_code, btn) {
    const original = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '…';

    fetch('../crud/new_link_code.php', {
        method : 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body   : 'short_code=' + encodeURIComponent(short_code)
    })
        .then(r => r.json())
        .then(res => {
            if (!res.success) {
                btn.disabled = false;
                btn.innerHTML = original;
                Swal.fire({ icon: 'error', title: 'Could not issue a new link', text: res.message || 'Please try again.' });
                return;
            }

            // Nagbago ang code, kaya nagbago rin ang URL at ang id ng
            // card. Ang buong listahan ang kinukuhang muli sa halip na
            // tagpi-tagpiing ayusin ang isang card.
            fetchLinks(true);

            Swal.fire({
                icon : 'success',
                title: 'New link issued',
                html : `The old URL no longer works.<br>
                        <b style="letter-spacing:2px">${escHtml(res.short_code)}</b><br>
                        <span style="font-size:.9em;opacity:.75">Set an expiry before you send it.</span>`,
                confirmButtonColor: '#8b5cf6'
            }).then(() => {
                // Buksan ang panel ng BAGONG card kapag naipinta na.
                setTimeout(() => {
                    const panel = document.getElementById('exp-' + res.short_code)?.querySelector('.lnk-exp-panel');
                    if (panel) panel.hidden = false;
                }, 400);
            });
        })
        .catch(() => {
            btn.disabled = false;
            btn.innerHTML = original;
            Swal.fire({ icon: 'error', title: 'Network error', text: 'Please try again.' });
        });
}

function setExpiry(short_code, opts, btn) {
    if (opts.at === '') {
        Swal.fire({ icon: 'warning', title: 'Pick a date and time first', timer: 2000, showConfirmButton: false });
        return;
    }

    const body = new URLSearchParams({ short_code });
    Object.keys(opts).forEach(k => body.append(k, opts[k]));

    const original = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '…';

    fetch('../crud/set_link_expiry.php', {
        method : 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body   : body.toString()
    })
        .then(r => r.json())
        .then(res => {
            btn.disabled = false;
            btn.innerHTML = original;

            if (!res.success) {
                Swal.fire({ icon: 'error', title: 'Could not set expiry', text: res.message || 'Please try again.' });
                return;
            }

            // Ang sagot ng server ang bagong katotohanan — hindi ang
            // hinuha ng browser tungkol sa kahihinatnan ng pindot.
            const link = allLinks.find(l => l.short_code === short_code);
            if (link) {
                link.expires_at    = res.expires_at;
                link.expires_label = res.expires_label;
                link.expires_in    = res.expires_in;
                link.is_expired    = res.is_expired;
            }

            renderCards(allLinks);
            applyFilters();

            Swal.fire({
                icon : 'success',
                title: res.expires_at ? 'Expiry updated' : 'Expiry removed',
                text : res.expires_at ? ('Closes ' + res.expires_label) : 'This link will stay open until you deactivate it.',
                timer: 2200,
                showConfirmButton: false
            });
        })
        .catch(() => {
            btn.disabled = false;
            btn.innerHTML = original;
            Swal.fire({ icon: 'error', title: 'Network error', text: 'Please try again.' });
        });
}

// Isang orasan para sa lahat ng card, hindi isa kada card: dalawampung
// link ay dalawampung setInterval na magigising kada segundo.
let expiryRefreshPending = false;

setInterval(function () {
    document.querySelectorAll('.lnk-exp-badge[data-countdown]').forEach(el => {
        let left = parseInt(el.dataset.countdown, 10) - 1;
        el.dataset.countdown = left;

        const clock = el.querySelector('.lnk-exp-clock');
        if (clock) clock.textContent = humanLeft(left);

        el.classList.toggle('is-soon', left <= 900);

        if (left <= 0) {
            // Huwag hulaan kung ano ang hitsura ng expired — tanungin
            // ang server, na siya ring magsasabi kung nagbago pa ang
            // ibang bagay habang bukas ang pahina.
            //
            // Isang hiling lang kahit ilang link ang sabay na magsara:
            // iisang klase, iisang oras ng pagtatapos, at ang sagot ay
            // pareho para sa lahat ng card.
            el.removeAttribute('data-countdown');

            if (!expiryRefreshPending) {
                expiryRefreshPending = true;
                setTimeout(() => {
                    expiryRefreshPending = false;
                    fetchLinks(true);
                }, 1200);
            }
        }
    });
}, 1000);

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

// ─── Room code ────────────────────────────────────────────────────────────────
//
// Ang anim na digit na ipinapakita ng instruktor sa harapan. Ang
// server ang nagsasabi kung ano ito at ilang segundo ang natitira —
// hindi kinakalkula rito. Ang orasan ng laptop sa harapan ay hindi
// palaging tama, at ang orasan ng server ang nagpapasya kung
// tatanggapin ang tinipa ng estudyante; ilang segundong pagkakaiba
// ay sapat na para magpakita ng codeng tatanggihan naman.
//
// Isang tanong kada tatlumpung segundo, isang instruktor. Ang
// pagbibilang pababa ay sa browser, ang halaga ay sa server.

let rcCode      = null;   // ang short_code na nakabukas ngayon
let rcTimer     = null;
let rcLeft      = 0;
let rcModal     = null;

function openRoomCode(short_code, label, enabled) {
    rcCode = short_code;

    document.getElementById('rcSubject').textContent = label;
    document.getElementById('rcCode').textContent    = '------';
    document.getElementById('rcToggle').checked      = !!enabled;
    paintRoomState(!!enabled);

    if (!rcModal) {
        rcModal = new bootstrap.Modal(document.getElementById('roomCodeModal'));

        // Ang orasan ay tumitigil kapag isinara ang modal. Kung
        // hindi, patuloy pa ring nagtatanong ang pahina sa server
        // para sa isang codeng wala nang nakatingin.
        document.getElementById('roomCodeModal').addEventListener('hidden.bs.modal', stopRoomCode);
    }

    rcModal.show();
    pullRoomCode();

    clearInterval(rcTimer);
    rcTimer = setInterval(tickRoomCode, 1000);
}

function stopRoomCode() {
    clearInterval(rcTimer);
    rcTimer = null;
    rcCode  = null;
}

function tickRoomCode() {
    rcLeft--;

    if (rcLeft <= 0) {
        pullRoomCode();
        return;
    }

    paintRoomClock();
}

function paintRoomClock() {
    const step = 30;
    document.getElementById('rcBar').style.width = Math.max(0, (rcLeft / step) * 100) + '%';
    document.getElementById('rcLeft').textContent =
        rcLeft + (rcLeft === 1 ? ' second left' : ' seconds left');
}

function pullRoomCode() {
    if (!rcCode) return;

    const body = new URLSearchParams();
    body.append('short_code', rcCode);

    fetch('../crud/room_code.php', { method: 'POST', body })
        .then(r => r.json())
        .then(res => {
            if (!rcCode) return;   // isinara habang nasa daan

            if (!res.success) {
                document.getElementById('rcCode').textContent = '------';
                document.getElementById('rcLeft').textContent = res.message || 'Could not load the code.';
                stopRoomCode();
                return;
            }

            document.getElementById('rcCode').textContent = res.code;
            rcLeft = res.seconds_left;

            // Walang transition sa pagbabalik sa buo: kung hindi,
            // dahan-dahang bumabalik ang bar mula kaliwa pakanan at
            // mukhang paurong ang oras.
            const bar = document.getElementById('rcBar');
            bar.style.transition = 'none';
            bar.style.width = '100%';
            void bar.offsetWidth;          // pinipilit ang reflow
            bar.style.transition = '';

            paintRoomClock();
        })
        .catch(() => {
            document.getElementById('rcLeft').textContent = 'Connection problem — the code may be out of date.';
        });
}

function paintRoomState(on) {
    document.getElementById('rcState').textContent = on
        ? 'On — students must type this code to submit'
        : 'Off — students can submit without it';
}

document.addEventListener('DOMContentLoaded', () => {
    const toggle = document.getElementById('rcToggle');
    if (!toggle) return;

    toggle.addEventListener('change', function () {
        if (!rcCode) return;

        const want = this.checked;
        this.disabled = true;

        const body = new URLSearchParams();
        body.append('short_code', rcCode);
        body.append('enabled', want ? '1' : '0');

        fetch('../crud/set_room_code.php', { method: 'POST', body })
            .then(r => r.json())
            .then(res => {
                if (!res.success) {
                    // Ibinabalik ang switch sa dati: ang switch na
                    // nakabukas samantalang OFF ang server ay mas
                    // masahol pa sa walang switch — aakalain ng
                    // instruktor na protektado na ang klase.
                    this.checked = !want;
                    Swal.fire({ icon: 'error', title: 'Could not change that', text: res.message || 'Please try again.' });
                    return;
                }

                paintRoomState(want);

                // Ang kulay ng pindutan sa card ay nagsasabi kung
                // nakabukas ito, kaya kailangang muling ipinta.
                fetchLinks();
            })
            .catch(() => {
                this.checked = !want;
                Swal.fire({ icon: 'error', title: 'Connection problem', text: 'Please try again.' });
            })
            .finally(() => {
                this.disabled = false;
            });
    });
});

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