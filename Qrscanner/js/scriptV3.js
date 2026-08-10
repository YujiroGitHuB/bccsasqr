/* ============================================================
   scriptV3.js — QR Scanner + Dynamic Island (merged)
   ============================================================ */

/* ── DOM References ─────────────────────────────────────── */
const video         = document.getElementById('video');
const qrResult      = document.getElementById('qrResult');
const subjectSelect = document.getElementById('subjectSelect');
const scannerStatus = document.getElementById('scannerStatus');
const beep          = new Audio("https://actions.google.com/sounds/v1/cartoon/wood_plank_flicks.ogg");

/* ── Scanner State ──────────────────────────────────────── */
let stream           = null;
let scanning         = false;
let lastDetectedCode = '';
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
        diTime.textContent = getNow();

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

function showStudentCard(student, subject, time) {
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

    // Ang initials ay madaling mapagkamalang totoong photo sa sulyap.
    // Sinasabi natin nang tahasan na walang mukhang maikukumpara.
    const subjectEl = document.getElementById('cardSubject');
    if (student.photo_url) {
        subjectEl.textContent = '✓ ' + subject;
        subjectEl.classList.remove('no-photo');
    } else {
        subjectEl.textContent = '⚠ No photo — identity not verified';
        subjectEl.classList.add('no-photo');
    }
    document.getElementById('cardTime').innerHTML      =
        time + '<br><span style="color:#38bdf8">' + getToday() + '</span>';

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
        beep.play();
        TTSManager.speak('Please select a subject first!');
        return;
    }

    debugLog(`QR Code scanned: ${text}`);
    const student = parseStudentFormat(text);
    if (!student) {
        qrResult.style.color = '#f87171';
        qrResult.textContent = 'Invalid QR format!';
        qrResult.className   = 'error';
        beep.play();
        navigator.vibrate?.(150);
        TTSManager.speak('Invalid QR Format!');
        return;
    }

    debugLog(`Student number parsed: ${student.id}`);
    const time = new Date().toLocaleTimeString();
    debugLog('Sending to server...');

    fetch('../crud/save_attendance.php', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            date:         getToday(),
            id:           student.id,
            subject:      selectedSubjectName,
            subject_code: selectedSubject,
            instructor:   instructorName,
            time:         time,
            user_id:      loggedUserId
        })
    })
    .then(res => { debugLog('Server response received'); return res.json(); })
    .then(response => {
        debugLog(`Server response: ${JSON.stringify(response)}`);

        if (response.success) {

            // ── Attendance table ──
            addToAttendance(getToday(), {
                id:      student.id,
                name:    response.name    ?? student.id,
                course:  response.course  ?? '',
                section: response.section ?? '',
                subject: selectedSubjectName,
                time
            });

            // ── Inline student card (inside #result) ──
            showStudentCard({
                name:      response.name      ?? student.id,
                course:    response.course    ?? '',
                section:   response.section   ?? '',
                photo_url: response.photo_url ?? null,
            }, selectedSubjectName, time);

            // ── Dynamic Island (top center) ──
            DynamicIsland.show({
                name:     response.name      ?? student.id,
                subject:  selectedSubjectName,
                photoUrl: response.photo_url ?? null,
            });

            if (response.photo_missing) {
                // Naitala ang attendance, pero walang mukhang maipapakita —
                // walang paraan ang instructor na tiyaking siya nga ang
                // may hawak ng QR. Sinasabi natin ito nang malinaw sa
                // halip na tahimik na magpakita ng initials.
                qrResult.textContent =
                    `✓ ${response.name ?? student.id} — ⚠ no photo, identity not verified`;
                qrResult.style.color = '#facc15';
                qrResult.className   = 'warning';
            } else {
                qrResult.textContent = `✓ ${response.name ?? student.id} - ${selectedSubjectName}`;
                qrResult.style.color = '#4ade80';
                qrResult.className   = 'success';
            }
            beep.play();
            navigator.vibrate?.([50, 30, 50]);
            TTSManager.speak(`Time in recorded for ${response.name ?? student.id} in ${selectedSubjectName}.`);

        } else if (response.message === 'already_marked') {
            qrResult.textContent = `⚠ Already marked: ${student.id}`;
            qrResult.style.color = '#facc15';
            qrResult.className   = 'warning';
            beep.play(); navigator.vibrate?.(200);
            TTSManager.speak('Already marked today.');

        } else if (response.message === 'not_authorized') {
            qrResult.textContent = '✗ Subject not assigned to you';
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            beep.play(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('You are not authorized for this subject.');
            Swal.fire({ icon: 'error', title: 'Not Authorized',
                html: `<p class="text-warning">This subject is not assigned to you.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else if (response.message === 'student_not_found') {
            qrResult.textContent = `✗ Student ${student.id} not found`;
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            beep.play(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('Student not found in database.');
            Swal.fire({ icon: 'error', title: 'Student Not Found',
                html: `<p>Student Number: <strong>${student.id}</strong></p>
                       <p class="text-warning">Not registered in the system.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else if (response.message === 'subject_section_mismatch') {
            qrResult.textContent = `✗ Section not covered by ${selectedSubjectName}`;
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            beep.play(); navigator.vibrate?.([100, 50, 100]);
            TTSManager.speak('Section mismatch.');
            Swal.fire({ icon: 'error', title: 'Section Not Covered',
                html: `<p class="text-warning">Student's section is not covered by <strong>${selectedSubjectName}</strong>.</p>`,
                confirmButtonColor: '#38bdf8', background: '#0f172a', color: '#e2e8f0' });

        } else if (response.message === 'photo_required') {
            // Naka-ON ang "Require student photo for scanning" at walang
            // photo ang estudyante — hindi naitala ang attendance.
            qrResult.textContent = '✗ No photo on file — cannot verify identity';
            qrResult.style.color = '#f87171';
            qrResult.className   = 'error';
            beep.play(); navigator.vibrate?.([100, 50, 100]);
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
            beep.play();
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
function tick() {
    if (!scanning) return;
    if (video.readyState === video.HAVE_ENOUGH_DATA) {
        const canvas  = document.createElement('canvas');
        canvas.width  = video.videoWidth;
        canvas.height = video.videoHeight;
        const ctx     = canvas.getContext('2d');
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);

        if (typeof jsQR === 'undefined') {
            debugLog('jsQR library not loaded!', 'error');
            scanning = false;
            return;
        }

        const code = jsQR(imgData.data, canvas.width, canvas.height);
        if (code?.location) {
            drawDetectionBox(code.location);
            if (code.data !== lastDetectedCode) {
                lastDetectedCode = code.data;
                handleScanned(code.data);
                setTimeout(() => { lastDetectedCode = ''; }, 1500);
            }
        } else {
            clearDetectionBox();
        }
    }
    requestAnimationFrame(tick);
}

/* ============================================================
   ATTENDANCE TABLE
   ============================================================ */
function addToAttendance(date, student) {
    $('#attendanceTable').DataTable().row.add([
        date, student.id, student.name,
        student.course, student.section,
        student.subject, student.time
    ]).draw(false);
}

/* ============================================================
   SUBJECT SELECT EVENT
   ============================================================ */
subjectSelect.addEventListener('change', function () {
    const selected      = this.options[this.selectedIndex];
    selectedSubject     = this.value;
    selectedSubjectName = selected.getAttribute('data-name');

    if (selectedSubject) {
        scannerStatus.textContent = `Ready to scan for: ${selectedSubjectName}`;
        scannerStatus.classList.add('active');
        if (!stream) startCamera();
    } else {
        scannerStatus.textContent = 'Please select a subject first';
        scannerStatus.classList.remove('active');
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
        // Nag-e-expire ang session kapag matagal nakatiwangwang ang tab
        // sa telepono. Object ang isinasauli ng API kapag ganoon
        // ({error: "Not logged in"}), hindi array — kaya lumalabas noon
        // ang malabong "data.forEach is not a function" sa screen.
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
                r.subject || 'N/A', r.time_in
            ]).draw(false);
        });
    })
    .catch(err => { debugLog(`Error loading attendance: ${err.message}`, 'error'); });

    updateStatusLabel();
    setInterval(updateStatusLabel, 5000);
};