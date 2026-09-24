/* ============================================================
   scriptV3.js — QR Scanner + Dynamic Island (merged)
   ============================================================ */

/* ── DOM References ─────────────────────────────────────── */
const video         = document.getElementById('video');
const qrResult      = document.getElementById('qrResult');
const subjectSelect = document.getElementById('subjectSelect');
const scannerStatus = document.getElementById('scannerStatus');
const beep          = new Audio("https://actions.google.com/sounds/v1/cartoon/wood_plank_flicks.ogg");
beep.preload = 'auto';

/* A single Audio element ignores play() while it is still playing, so on
   back-to-back scans the second scan used to go silent. Rewinding first
   makes every scan sound. */
function playBeep() {
    try {
        beep.currentTime = 0;
        beep.play().catch(() => {});
    } catch (e) { /* autoplay policy — the vibration still fires */ }
}

/* ── Scanner State ──────────────────────────────────────── */
let stream           = null;
let scanning         = false;
let lastDetectedCode = '';
let lastCodeTimer    = null;
let lastErrorTime    = 0;
const ERROR_COOLDOWN = 3000;
let selectedSubject     = null;
let selectedSubjectName = null;

/* ============================================================
   DYNAMIC ISLAND
   ============================================================ */
const DynamicIsland = (() => {

    // #di-outer       — outer wrapper, handles show/hide and di-expanded class
    // #dynamic-island — the pill itself, handles the di-scanning pulse animation
    const outer   = document.getElementById('di-outer');
    const pill    = document.getElementById('dynamic-island');
    const diPhoto = document.getElementById('di-photo');
    const diInit  = document.getElementById('di-initials');
    const diName  = document.getElementById('di-name');
    const diSubj  = document.getElementById('di-subject');
    const diTime  = document.getElementById('di-time');
    const diProg  = document.getElementById('di-progress');

    const DISMISS_MS = 5000;
    let _timer = null;

    function getInitials(fullName) {
        return (fullName || '?')
            .trim().split(' ').filter(Boolean)
            .slice(0, 2).map(w => w[0].toUpperCase()).join('');
    }

    function getNow() {
        return new Date().toLocaleTimeString('en-US', {
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true
        });
    }

    function startDismissTimer() {
        clearTimeout(_timer);
        diProg.style.transition = 'none';
        diProg.style.width      = '0%';
        void diProg.offsetWidth;
        diProg.style.transition = `width ${DISMISS_MS}ms linear`;
        diProg.style.width      = '100%';
        _timer = setTimeout(collapse, DISMISS_MS);
    }

    function collapse() {
        clearTimeout(_timer);
        outer.classList.remove('di-expanded');
        diProg.style.transition = 'none';
        diProg.style.width      = '0%';
        // hide the wrapper after the collapse animation finishes
        setTimeout(() => { outer.style.display = 'none'; }, 500);
    }

    /**
     * Show student info on the Dynamic Island.
     * @param {Object} data
     * @param {string}  data.name      - Full name of the student
     * @param {string}  data.subject   - Subject name
     * @param {string} [data.photoUrl] - Photo URL (optional; falls back to initials)
     */
    function show(data) {
        diName.textContent = data.name    || 'Unknown Student';
        diSubj.textContent = data.subject || '';
        diTime.textContent = data.time || getNow();
        if (data.late) {
            const tag = document.createElement('span');
            tag.className   = 'di-late';
            tag.textContent = 'LATE';
            diTime.append(' · ', tag);
        }

        if (data.photoUrl) {
            const img  = new Image();
            img.onload = () => {
                diPhoto.src           = data.photoUrl;
                diPhoto.style.display = 'block';
                diInit.style.display  = 'none';
            };
            img.onerror = () => {
                diPhoto.style.display = 'none';
                diInit.style.display  = 'flex';
                diInit.textContent    = getInitials(data.name);
            };
            img.src = data.photoUrl;
        } else {
            diPhoto.style.display = 'none';
            diInit.style.display  = 'flex';
            diInit.textContent    = getInitials(data.name);
        }

        // Reset states
        outer.classList.remove('di-expanded');
        pill.classList.remove('di-scanning');
        outer.style.display = 'flex'; // make the wrapper visible before animating
        void pill.offsetWidth;

        // Trigger pulse on the pill, then expand the island
        pill.classList.add('di-scanning');
        setTimeout(() => {
            outer.classList.add('di-expanded');
            startDismissTimer();
        }, 200);
    }

    return { show, collapse };

})();

/* ============================================================
   INLINE STUDENT CARD (inside #result area — kept alongside the island)
   ============================================================ */
let cardTimer = null;

function showStudentCard(student, subject, time, late = false) {
    const card     = document.getElementById('studentCard');
    const photo    = document.getElementById('cardPhoto');
    const initials = document.getElementById('cardInitials');

    if (student.photo_url) {
        photo.src              = student.photo_url;
        photo.style.display    = 'block';
        initials.style.display = 'none';
    } else {
        photo.style.display    = 'none';
        initials.style.display = 'flex';
        initials.textContent   = (student.name || '?')
            .split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
    }

    document.getElementById('cardName').textContent    = student.name;
    document.getElementById('cardMeta').textContent    =
        [student.course, student.section].filter(Boolean).join(' — ');

    // At a glance, initials are easily mistaken for a real photo. Say
    // outright that there is no face to compare against.
    const subjectEl = document.getElementById('cardSubject');
    if (student.photo_url) {
        subjectEl.textContent = '✓ ' + subject;
        subjectEl.classList.remove('no-photo');
    } else {
        subjectEl.textContent = '⚠ No photo — identity not verified';
        subjectEl.classList.add('no-photo');
    }
    document.getElementById('cardTime').innerHTML      =
        time + '<br>' + (late
            ? '<span class="scan-late-tag">Late</span>'
            : '<span style="color:#38bdf8">' + getToday() + '</span>');

    card.style.display = 'none';
    void card.offsetWidth;
    card.style.display = 'flex';

    clearTimeout(cardTimer);
    cardTimer = setTimeout(() => { card.style.display = 'none'; }, 5000);
}

/* ============================================================
   OVERLAY CANVAS (QR detection box)
   ============================================================ */
const overlayCanvas = document.createElement('canvas');
overlayCanvas.id                     = 'detectionCanvas';
overlayCanvas.style.position         = 'absolute';
overlayCanvas.style.top              = '0';
overlayCanvas.style.left             = '0';
overlayCanvas.style.width            = '100%';
overlayCanvas.style.height           = '100%';
overlayCanvas.style.pointerEvents    = 'none';
overlayCanvas.style.zIndex           = '4';

const scannerContainer = document.getElementById('scannerContainer');
if (!scannerContainer) {
    debugLog('Scanner container not found!', 'error');
} else {
    scannerContainer.appendChild(overlayCanvas);
    debugLog('Overlay canvas added successfully');
}

/* ============================================================
   HELPERS
   ============================================================ */
function getToday() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
}

function debugLog(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
    if (type === 'error') {
        qrResult.textContent  = `Error: ${message}`;
        qrResult.style.color  = '#f87171';
    }
}

function updateStatusLabel() {
    if (selectedSubject) {
        qrResult.textContent = `Scanning for ${selectedSubjectName} - ${getToday()}`;
    } else {
        qrResult.textContent = `Select subject first - ${getToday()}`;
    }
    qrResult.style.color = '#94a3b8';
}

function parseStudentFormat(text) {
    const studentNo = text.trim();
    if (!/^\d{3}-\d{3,4}$/.test(studentNo)) {
        const now = Date.now();
        if (now - lastErrorTime > ERROR_COOLDOWN) {
            lastErrorTime = now;
            debugLog('Invalid QR format', 'error');
            Swal.fire({
                icon: 'error', title: 'Invalid QR Code',
                text: 'This QR code is not a valid BCC student QR.',
                timer: 2000, showConfirmButton: false,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0'
            });
        }
        return null;
    }
    debugLog(`Parsed student number: ${studentNo}`);
    return { id: studentNo };
}

/* ============================================================
   CAMERA
   ============================================================ */
async function startCamera() {
    debugLog('Starting camera...');
    if (!navigator.mediaDevices?.getUserMedia) {
        debugLog('getUserMedia not supported!', 'error');
        alert('Your browser does not support camera access.');
        return;
    }
    try {
        debugLog('Requesting camera permission...');
        stream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
        });
        debugLog('Camera access granted!');
        if (!video) { debugLog('Video element not found!', 'error'); return; }
        video.srcObject = stream;
        video.play();
        scanning = true;
        video.addEventListener('loadedmetadata', () => {
            debugLog(`Video loaded: ${video.videoWidth}x${video.videoHeight}`);
            overlayCanvas.width  = video.videoWidth;
            overlayCanvas.height = video.videoHeight;
        });
        updateStatusLabel();
        requestAnimationFrame(tick);
    } catch (e) {
        debugLog(`Camera error: ${e.name} - ${e.message}`, 'error');
        let msg = 'Cannot access camera: ';
        if      (e.name === 'NotAllowedError')   msg += 'Permission denied.';
        else if (e.name === 'NotFoundError')     msg += 'No camera found.';
        else if (e.name === 'NotReadableError')  msg += 'Camera in use by another app.';
        else                                     msg += e.message;
        alert(msg);
    }
}

/* ============================================================
   DETECTION BOX DRAWING
   ============================================================ */
function drawDetectionBox(location) {
    const ctx    = overlayCanvas.getContext('2d');
    const scaleX = overlayCanvas.width  / video.videoWidth;
    const scaleY = overlayCanvas.height / video.videoHeight;

    ctx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);

    // Outline
    ctx.beginPath();
    ctx.strokeStyle = '#00ff88';
    ctx.lineWidth   = 4;
    ctx.shadowColor = '#00ff88';
    ctx.shadowBlur  = 15;
    ctx.moveTo(location.topLeftCorner.x     * scaleX, location.topLeftCorner.y     * scaleY);
    ctx.lineTo(location.topRightCorner.x    * scaleX, location.topRightCorner.y    * scaleY);
    ctx.lineTo(location.bottomRightCorner.x * scaleX, location.bottomRightCorner.y * scaleY);
    ctx.lineTo(location.bottomLeftCorner.x  * scaleX, location.bottomLeftCorner.y  * scaleY);
    ctx.lineTo(location.topLeftCorner.x     * scaleX, location.topLeftCorner.y     * scaleY);
    ctx.stroke();

    // Corner accents
    const cornerSize = 20;
    const corners    = [
        location.topLeftCorner, location.topRightCorner,
        location.bottomRightCorner, location.bottomLeftCorner
    ];
    ctx.strokeStyle = '#00ff88';
    ctx.lineWidth   = 6;
    ctx.lineCap     = 'round';
    corners.forEach((corner, i) => {
        const x = corner.x * scaleX;
        const y = corner.y * scaleY;
        ctx.beginPath();
        if      (i === 0) { ctx.moveTo(x, y + cornerSize); ctx.lineTo(x, y); ctx.lineTo(x + cornerSize, y); }
        else if (i === 1) { ctx.moveTo(x - cornerSize, y); ctx.lineTo(x, y); ctx.lineTo(x, y + cornerSize); }
        else if (i === 2) { ctx.moveTo(x, y - cornerSize); ctx.lineTo(x, y); ctx.lineTo(x - cornerSize, y); }
        else              { ctx.moveTo(x + cornerSize, y); ctx.lineTo(x, y); ctx.lineTo(x, y - cornerSize); }
        ctx.stroke();

        ctx.beginPath();
        ctx.fillStyle = '#00ff88';
        ctx.arc(x, y, 5, 0, Math.PI * 2);
        ctx.fill();
    });

    // Center dot
    const cx = ((location.topLeftCorner.x + location.bottomRightCorner.x) / 2) * scaleX;
    const cy = ((location.topLeftCorner.y + location.bottomRightCorner.y) / 2) * scaleY;
    ctx.beginPath(); ctx.fillStyle = '#00ff88'; ctx.arc(cx, cy, 8, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.strokeStyle = 'rgba(0,255,136,0.5)'; ctx.lineWidth = 2; ctx.arc(cx, cy, 15, 0, Math.PI * 2); ctx.stroke();
}

function clearDetectionBox() {
    overlayCanvas.getContext('2d').clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
}

/* ============================================================
   SCAN HANDLER
   ============================================================ */
function handleScanned(text) {
    if (!selectedSubject) {
        qrResult.style.color  = '#f87171';
        qrResult.textContent  = 'Please select a subject first!';
        qrResult.className    = 'error';
        playBeep();
        TTSManager.speak('Please select a subject first!');
        return;
    }

    debugLog(`QR Code scanned: ${text}`);
    const student = parseStudentFormat(text);
    if (!student) {
        qrResult.style.color = '#f87171';
        qrResult.textContent = 'Invalid QR format!';
        qrResult.className   = 'error';
        playBeep();
        navigator.vibrate?.(150);
        TTSManager.speak('Invalid QR Format!');
        return;
    }

    debugLog(`Student number parsed: ${student.id}`);
    debugLog('Sending to server...');

    // Which student and which subject — nothing else. Who is scanning,
    // the date and the time are the server's to decide (see the top of
    // crud/save_attendance.php); sending them only invited a changed
    // copy.
    fetch('../crud/save_attendance.php', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            id:           student.id,
            subject_code: selectedSubject
        })
    })
    .then(res => { debugLog('Server response received'); return res.json(); })
    .then(response => {
        debugLog(`Server response: ${JSON.stringify(response)}`);

        if (response.success) {
            // Late is the server's answer (the database clock against the
            // subject's cutoff), carried to every place the scan shows.
            const late = response.late === true;

            // The time and date that were stored, so the screen never
            // shows a different minute from the record.
            const time = response.time_in ?? new Date().toLocaleTimeString();

            // ── Attendance table ──
            addToAttendance(response.date ?? getToday(), {
                id:      student.id,
                name:    response.name    ?? student.id,
                course:  response.course  ?? '',
                section: response.section ?? '',
                subject: selectedSubjectName,
                time,
                late
            });

            // ── Inline student card (inside #result) ──
            showStudentCard({
                name:      response.name      ?? student.id,
                course:    response.course    ?? '',
                section:   response.section   ?? '',
                photo_url: response.photo_url ?? null,
            }, selectedSubjectName, time, late);

            // ── Dynamic Island (top center) ──
            DynamicIsland.show({
                name:     response.name      ?? student.id,
                subject:  selectedSubjectName,
                photoUrl: response.photo_url ?? null,
                time,
                late
            });

            if (response.photo_missing) {
                // Attendance was recorded, but there is no face to show —
                // the instructor has no way to confirm this is really the
                // person holding the QR. Say so plainly instead of
                // quietly showing initials.
                qrResult.textContent =
                    `✓ ${response.name ?? student.id}${late ? ' — LATE' : ''} — ⚠ no photo, identity not verified`;
                qrResult.style.color = '#facc15';
                qrResult.className   = 'warning';
            } else if (late) {
                qrResult.textContent = `✓ ${response.name ?? student.id} — LATE (after ${response.late_label ?? 'the cutoff'})`;
                qrResult.style.color = '#facc15';
                qrResult.className   = 'warning';
            } else {
                qrResult.textContent = `✓ ${response.name ?? student.id} - ${selectedSubjectName}`;
                qrResult.style.color = '#4ade80';
                qrResult.className   = 'success';
            }
            playBeep();
            navigator.vibrate?.([50, 30, 50]);
            // The name is read, not the raw record: the school export is
            // all-caps, which every voice spells out letter by letter.
            // Kept to one short phrase — the old sentence ran long
            // enough that the next scan cut it off mid-name. "Late" is
            // one word more, and the instructor may not be looking.
            TTSManager.speak(`${TTSManager.nameForSpeech(response.name) || student.id}, recorded${late ? ' late' : ''}.`);

        } else if (response.message === 'already_marked') {
            qrResult.textContent = `⚠ Already marked: ${student.id}`;
            qrResult.style.color = '#facc15';
            qrResult.className   = 'warning';
            playBeep(); navigator.vibrate?.(200);
            TTSManager.speak('Already marked today.');

        } else if (response.message === 'not_authorized') {
            qrResult.textContent = '✗ Subject not assigned to you';
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            playBeep(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('You are not authorized for this subject.');
            Swal.fire({ icon: 'error', title: 'Not Authorized',
                html: `<p class="text-warning">This subject is not assigned to you.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else if (response.message === 'student_not_found') {
            qrResult.textContent = `✗ Student ${student.id} not found`;
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            playBeep(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('Student not found in database.');
            Swal.fire({ icon: 'error', title: 'Student Not Found',
                html: `<p>Student Number: <strong>${student.id}</strong></p>
                       <p class="text-warning">Not registered in the system.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else if (response.message === 'subject_section_mismatch') {
            qrResult.textContent = `✗ Section not covered by ${selectedSubjectName}`;
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            playBeep(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('Section mismatch.');
            Swal.fire({ icon: 'error', title: 'Section Not Covered',
                html: `<p class="text-warning">Student's section is not covered by <strong>${selectedSubjectName}</strong>.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else if (response.message === 'photo_required') {
            // "Require student photo for scanning" is ON and the student
            // has no photo — attendance was not recorded.
            qrResult.textContent = '✗ No photo on file — cannot verify identity';
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            playBeep(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('Student photo required.');
            Swal.fire({
                icon: 'error',
                title: 'Student Photo Required',
                html: `<p><strong>${response.name ?? student.id}</strong> has no photo on file.</p>
                       <p class="text-warning">Attendance was not recorded. Ask the admin to
                       upload a photo first.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0'
            });

        } else if (response.message === 'not_enrolled') {
            qrResult.textContent = `✗ Student not enrolled in ${selectedSubjectName}`;
            qrResult.style.color = '#f87171';
            playBeep();
            TTSManager.speak(`Student is not enrolled in ${selectedSubjectName}.`);
            Swal.fire({ icon: 'error', title: 'Not Enrolled',
                html: `<p>Student <strong>${student.id}</strong> is not enrolled in <strong>${selectedSubjectName}</strong></p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else {
            qrResult.textContent = '✗ Error saving attendance';
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            debugLog(`Save failed: ${response.message}`, 'error');
            TTSManager.speak('Error saving attendance.');
            if (response.error) {
                Swal.fire({ icon: 'error', title: 'Error', text: response.error,
                    confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });
            }
        }
    })
    .catch(err => {
        debugLog(`Fetch error: ${err.message}`, 'error');
        qrResult.textContent = '✗ Network error';
        qrResult.style.color = '#f87171';
        TTSManager.speak('Network error. Please check connection.');
    });
}

/* ============================================================
   SCAN LOOP
   ============================================================ */
/* The frame the decoder actually reads. It is built once and reused —
   the old loop allocated a fresh 1280x720 canvas on every animation
   frame, then asked jsQR to read all 900k pixels of it. That is what
   made the camera stutter and each scan feel a beat late; a QR code
   only needs a fraction of that resolution to decode. */
const SCAN_WIDTH   = 640;   // downscaled frame sent to jsQR
const SCAN_INTERVAL = 80;   // ms between decode attempts (~12/sec)

const scanCanvas = document.createElement('canvas');
const scanCtx    = scanCanvas.getContext('2d', { willReadFrequently: true });
let   lastScanAt = 0;

function tick(now = 0) {
    if (!scanning) return;
    requestAnimationFrame(tick);

    if (video.readyState !== video.HAVE_ENOUGH_DATA) return;
    if (now - lastScanAt < SCAN_INTERVAL) return;
    lastScanAt = now;

    if (typeof jsQR === 'undefined') {
        debugLog('jsQR library not loaded!', 'error');
        scanning = false;
        return;
    }

    const scale = Math.min(1, SCAN_WIDTH / video.videoWidth);
    const w     = Math.round(video.videoWidth  * scale);
    const h     = Math.round(video.videoHeight * scale);
    if (scanCanvas.width !== w || scanCanvas.height !== h) {
        scanCanvas.width  = w;
        scanCanvas.height = h;
    }
    scanCtx.drawImage(video, 0, 0, w, h);
    const imgData = scanCtx.getImageData(0, 0, w, h);

    // Both passes are needed. The generator draws the code light-on-dark
    // (colorDark #38bdf8 on colorLight #0f172a in QRgenerator/js/
    // scriptv2.js), so the inverted pass is the one that reads a BCC QR
    // off a screen — while a photocopied or reprinted code comes in the
    // usual dark-on-light. Skipping either one stops the scanner dead.
    const code = jsQR(imgData.data, w, h, { inversionAttempts: 'attemptBoth' });

    if (code?.location) {
        // The box is drawn over the full-size video, so the corners have
        // to come back out of the downscaled frame.
        drawDetectionBox(scaleLocation(code.location, 1 / scale));
        if (code.data !== lastDetectedCode) {
            lastDetectedCode = code.data;
            handleScanned(code.data);
            // One timer only: without this, the timer from the previous
            // student would clear the guard for the current one and the
            // same code would fire twice.
            clearTimeout(lastCodeTimer);
            lastCodeTimer = setTimeout(() => { lastDetectedCode = ''; }, 1500);
        }
    } else {
        clearDetectionBox();
    }
}

function scaleLocation(loc, k) {
    const p = c => ({ x: c.x * k, y: c.y * k });
    return {
        topLeftCorner:     p(loc.topLeftCorner),
        topRightCorner:    p(loc.topRightCorner),
        bottomRightCorner: p(loc.bottomRightCorner),
        bottomLeftCorner:  p(loc.bottomLeftCorner)
    };
}

/* ============================================================
   ATTENDANCE TABLE
   ============================================================ */
// The Late tag rides in the Time cell rather than a column of its own:
// the table is sorted and searched by position, and "Late" beside the
// time is where the eye already is.
function timeCell(time, late) {
    return late ? `${time} <span class="scan-late-tag">Late</span>` : time;
}

function addToAttendance(date, student) {
    $('#attendanceTable').DataTable().row.add([
        date, student.id, student.name,
        student.course, student.section,
        student.subject, timeCell(student.time, student.late)
    ]).draw(false);
}

/* ============================================================
   LATE TIME
   The cutoff for the selected subject: "on time until 8:15", and every
   scan after that minute is saved as late. crud/save_attendance.php
   decides it on the database clock — this only shows and sets it.
   Every subject's state arrived with the page (scanLateStates), and
   all of them count down together, so switching subjects never shows
   a stale countdown.
   ============================================================ */
const ScanLate = (() => {
    const box      = document.getElementById('scanLate');
    const pill     = document.getElementById('scanLatePill');
    const icon     = document.getElementById('scanLateIcon');
    const text     = document.getElementById('scanLateText');
    const btn      = document.getElementById('scanLateBtn');
    const btnIcon  = document.getElementById('scanLateBtnIcon');
    const btnText  = document.getElementById('scanLateBtnText');
    const panel    = document.getElementById('scanLatePanel');
    const atInput  = document.getElementById('scanLateAt');
    const clearBtn = document.getElementById('scanLateClear');

    const states = (typeof scanLateStates === 'object' && scanLateStates) || {};
    let code = '';

    const SWAL_SCAN = { background: '#0f172a', color: '#e2e8f0', confirmButtonColor: '#38bdf8' };

    const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
    const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ESC[c]);

    function fmtLeft(left) {
        const h = Math.floor(left / 3600);
        const m = Math.floor((left % 3600) / 60);
        const s = left % 60;
        const pad = n => String(n).padStart(2, '0');
        return h > 0 ? `${h}h ${pad(m)}m` : (m > 0 ? `${m}m ${pad(s)}s` : `${s}s`);
    }

    function paint() {
        box.hidden = !code;
        if (!code) return;

        const st = states[code];
        pill.classList.remove('is-none', 'is-ok', 'is-late');

        if (!st || !st.late_on) {
            pill.classList.add('is-none');
            icon.className      = 'bi bi-alarm';
            text.textContent    = 'No late time';
            btnIcon.className   = 'bi bi-plus-lg';
            btnText.textContent = 'Set late time';
            clearBtn.hidden     = true;
            return;
        }

        const label = esc(st.late_label);
        btnIcon.className   = 'bi bi-pencil';
        btnText.textContent = 'Change';
        clearBtn.hidden     = false;

        if (st.late_in > 0) {
            pill.classList.add('is-ok');
            icon.className = 'bi bi-alarm';
            text.innerHTML = `On time until <b>${label}</b> · <span class="scan-late-left">${fmtLeft(st.late_in)}</span> left`;
        } else {
            pill.classList.add('is-late');
            icon.className = 'bi bi-alarm-fill';
            text.innerHTML = `Marking late · after <b>${label}</b>`;
        }
    }

    function select(subjectCode) {
        code = subjectCode || '';
        panel.hidden = true;
        btn.setAttribute('aria-expanded', 'false');
        paint();
    }

    function save(opts, trigger) {
        if (!code) return;
        if (opts.at === '') {
            Swal.fire({ ...SWAL_SCAN, icon: 'warning', title: 'Pick a time first', timer: 1800, showConfirmButton: false });
            return;
        }

        const body = new URLSearchParams({ subject_code: code });
        Object.keys(opts).forEach(k => body.append(k, opts[k]));

        const forCode = code;
        if (trigger) trigger.disabled = true;

        fetch('../crud/set_scan_late.php', { method: 'POST', body })
            .then(r => r.json())
            .then(res => {
                if (!res.success) throw new Error(res.message || 'Could not set the late time.');

                states[forCode] = { late_on: res.late_on, late_in: res.late_in, late_label: res.late_label };
                panel.hidden = true;
                btn.setAttribute('aria-expanded', 'false');
                paint();

                // A time already behind us is usually a slip — 8:15 typed
                // at 3 PM, AM where PM was meant — so it asks to be read.
                if (res.late_on && res.late_in <= 0) {
                    Swal.fire({
                        ...SWAL_SCAN, icon: 'warning',
                        title: `${esc(res.late_label)} has already passed`,
                        html: `Every scan from now on will be saved as <b>late</b>.<br>
                               <span style="font-size:.9em;opacity:.75">If you meant a later time — PM instead of AM — tap Change and set it again.</span>`
                    });
                } else {
                    Swal.fire({
                        ...SWAL_SCAN, icon: 'success', timer: 2000, showConfirmButton: false,
                        title: res.late_on ? 'Late time set' : 'Late time removed',
                        text:  res.late_on
                            ? `On time until ${res.late_label}. Scans after that are saved as late.`
                            : 'Every scan counts as on time.'
                    });
                }
            })
            .catch(err => Swal.fire({ ...SWAL_SCAN, icon: 'error', title: 'Could not set late time', text: err.message }))
            .finally(() => { if (trigger) trigger.disabled = false; });
    }

    btn.addEventListener('click', () => {
        panel.hidden = !panel.hidden;
        btn.setAttribute('aria-expanded', String(!panel.hidden));
    });
    panel.querySelectorAll('[data-minutes]').forEach(b =>
        b.addEventListener('click', () => save({ minutes: b.dataset.minutes }, b)));
    document.getElementById('scanLateSet').addEventListener('click', e => save({ at: atInput.value }, e.currentTarget));
    clearBtn.addEventListener('click', () => save({ clear: 1 }, clearBtn));

    // One clock for every subject. Only the selected one is repainted,
    // and only in full at the minute it turns late.
    setInterval(() => {
        Object.keys(states).forEach(c => {
            const st = states[c];
            if (!st || !st.late_on || !(st.late_in > 0)) return;
            st.late_in--;

            if (c !== code) return;
            if (st.late_in <= 0) { paint(); return; }
            const left = pill.querySelector('.scan-late-left');
            if (left) left.textContent = fmtLeft(st.late_in);
        });
    }, 1000);

    return { select };
})();

/* ============================================================
   SUBJECT SELECT EVENT
   ============================================================ */
/* ── Scan mode (phones) ───────────────────────────────────────────────────────
   Once a subject is picked, everything above the camera that is not
   needed gets hidden and the camera is pinned to the top of the screen.
   The layout itself lives in the CSS — this only switches it on and
   off. */
function setScanMode(on, subjectLabel) {
    document.body.classList.toggle('scan-mode', on);

    const chipSubject = document.getElementById('scanChipSubject');
    if (chipSubject) chipSubject.textContent = subjectLabel || '';
}

document.getElementById('scanChipChange')?.addEventListener('click', () => {
    // Leave scan mode so the full picker comes back, then bring it to
    // the user.
    setScanMode(false);
    subjectSelect.scrollIntoView({ behavior: 'smooth', block: 'center' });
    subjectSelect.focus();
});

subjectSelect.addEventListener('change', function () {
    const selected      = this.options[this.selectedIndex];
    selectedSubject     = this.value;
    selectedSubjectName = selected.getAttribute('data-name');
    ScanLate.select(selectedSubject);

    if (selectedSubject) {
        // On a phone the subject name is already in the chip — repeating
        // it costs two lines of space above the camera.
        const compact = window.matchMedia('(max-width: 768px)').matches;
        scannerStatus.textContent = compact
            ? 'Ready to scan'
            : `Ready to scan for: ${selectedSubjectName}`;
        scannerStatus.classList.add('active');
        setScanMode(true, `${selectedSubjectName} (${selectedSubject})`);
        if (!stream) startCamera();
    } else {
        scannerStatus.textContent = 'Please select a subject first';
        scannerStatus.classList.remove('active');
        setScanMode(false);
    }
});

/* ============================================================
   INIT
   ============================================================ */
window.onload = () => {
    debugLog('Page loaded, initializing...');
    if (typeof $    === 'undefined') { debugLog('jQuery not loaded!', 'error');      return; }
    if (typeof Swal === 'undefined') { debugLog('SweetAlert2 not loaded!', 'error');        }
    if (typeof jsQR === 'undefined') { debugLog('jsQR not loaded!', 'error');               }
    if (typeof loggedUserId === 'undefined') { debugLog('loggedUserId not defined!', 'error'); return; }
    debugLog(`User ID: ${loggedUserId}`);

    $('#attendanceTable').DataTable({
        responsive:  true,
        pageLength:  5,
        lengthMenu:  [5, 10, 20, 50],
        order:       [[0, 'desc']],
        language: {
            search:     'Search:',
            lengthMenu: 'Show _MENU_ entries',
            info:       'Showing _START_ to _END_ of _TOTAL_ records'
        }
    });

    debugLog('Fetching attendance records...');
    fetch('../crud/get_attendance.php', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ user_id: loggedUserId })
    })
    .then(res => res.json())
    .then(data => {
        // The session expires when a tab is left sitting for a long time
        // on a phone. When that happens the API returns an object
        // ({error: "Not logged in"}) rather than an array — which is why
        // a cryptic "data.forEach is not a function" used to appear on
        // screen.
        if (!Array.isArray(data)) {
            debugLog(data && data.error
                ? `Cannot load attendance: ${data.error}. Please sign in again.`
                : 'Cannot load attendance: unexpected response from server.', 'error');
            return;
        }

        debugLog(`Loaded ${data.length} attendance records`);
        const table = $('#attendanceTable').DataTable();
        data.forEach(r => {
            table.row.add([
                r.date, r.student_no, r.name,
                r.course, r.section,
                r.subject || 'N/A', timeCell(r.time_in, Number(r.is_late) === 1)
            ]).draw(false);
        });
    })
    .catch(err => { debugLog(`Error loading attendance: ${err.message}`, 'error'); });

    updateStatusLabel();
    setInterval(updateStatusLabel, 5000);
};