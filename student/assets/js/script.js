// ── CONFIG ────────────────────────────────────────────────
const API_VERIFY = 'student_photo_api.php?action=verify';
const API_SAVE   = 'student_photo_api.php?action=save';
const OUTPUT_SIZE = 300;   // 400 → 300px, still large enough for attendance
const OUTPUT_QUALITY = 0.75; // 0.88 → 0.75, mas maliit na file

// ── STATE ─────────────────────────────────────────────────
let cropper     = null,
    studentData = null,
    savedB64    = null,
    csrfToken   = '';

// Fetch CSRF token on page load
async function fetchCsrfToken() {
    try {
        const r = await fetch('student_photo_api.php?action=get_token');
        if (!r.ok) throw new Error('HTTP ' + r.status);
        const d = await r.json();
        if (d.success) { csrfToken = d.token; return true; }
        return false;
    } catch (e) {
        console.warn('CSRF token fetch failed:', e.message);
        return false;
    }
}
fetchCsrfToken();

// ── KEYBOARD FLOW ─────────────────────────────────────────
document.getElementById('inputStudentNo').addEventListener('keydown', e => {
    if (e.key === 'Enter') document.getElementById('inputLastName').focus();
});
document.getElementById('inputLastName').addEventListener('keydown', e => {
    if (e.key === 'Enter') verifyStudent();
});

// ── STEP 1: VERIFY ────────────────────────────────────────
async function verifyStudent() {
    const studentNo = document.getElementById('inputStudentNo').value.trim();
    const lastName  = document.getElementById('inputLastName').value.trim();

    if (!studentNo || !lastName) {
        showAlert(null, 'error', 'Please enter both your Student Number and Last Name.');
        return;
    }

    const btn = document.getElementById('btnVerify');
    setLoading(btn, true, 'Verifying…');

    if (!csrfToken) await fetchCsrfToken();

    try {
        const res  = await fetch(`${API_VERIFY}&student_id=${enc(studentNo)}&last_name=${enc(lastName)}&_token=${enc(csrfToken)}`);
        const data = await res.json();

        if (data.locked) {
            showAlert(null, 'warning', data.message || 'Too many failed attempts. Please try again later.');
            return;
        }

        if (data.success) {
            studentData = data.student;
            if (data.token) csrfToken = data.token;
            goStep2();
        } else {
            showAlert(null, 'error', data.message || 'Verification failed. Please try again.');
        }
    } catch {
        showAlert(null, 'error', 'Network error. Please check your connection.');
    } finally {
        setLoading(btn, false, '<i class="bi bi-shield-check"></i> Verify Identity');
    }
}

function goStep2() {
    const initials = studentData.name.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
    document.getElementById('vAvatar').textContent = initials;
    document.getElementById('vName').textContent   = studentData.name;
    document.getElementById('vMeta').textContent   = [studentData.course, studentData.year_level].filter(Boolean).join(' · ');
    setStep(2);
}

// ── STEP 2: UPLOAD & CROP ─────────────────────────────────
function handleFile(input) {
    const file = input.files[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
        showAlert(null, 'error', 'File too large. Maximum size is 5 MB.');
        input.value = '';
        return;
    }
    const reader = new FileReader();
    reader.onload  = e => initCropper(e.target.result);
    reader.readAsDataURL(file);
}

function initCropper(src) {
    document.getElementById('paneUpload').style.display  = 'none';
    document.getElementById('paneCamera').style.display  = 'none';
    document.getElementById('cropSection').style.display = 'block';

    if (cropper) { cropper.destroy(); cropper = null; }

    const img = document.getElementById('cropImg');
    img.src   = src;
    cropper   = new Cropper(img, {
        aspectRatio         : 1,
        viewMode            : 1,
        dragMode            : 'move',
        autoCropArea        : 0.78,
        restore             : false,
        guides              : false,
        center              : true,
        highlight           : false,
        cropBoxMovable      : true,
        cropBoxResizable    : true,
        toggleDragModeOnDblclick: false,
        preview             : '#crop-preview',
    });
}

function resetCrop() {
    if (cropper) { cropper.destroy(); cropper = null; }
    document.getElementById('cropSection').style.display = 'none';
    const isCamera = document.getElementById('tabCamera').classList.contains('active');
    document.getElementById('paneUpload').style.display  = isCamera ? 'none' : 'block';
    document.getElementById('paneCamera').style.display  = isCamera ? 'block' : 'none';
    document.getElementById('photoFile').value = '';
}

async function savePhoto() {
    if (!cropper || !studentData) return;

    const btn = document.getElementById('btnSave');
    setLoading(btn, true, 'Saving…');

    const canvas = cropper.getCroppedCanvas({
        width               : OUTPUT_SIZE,
        height              : OUTPUT_SIZE,
        imageSmoothingEnabled : true,
        imageSmoothingQuality : 'high',
    });
    const b64 = canvas.toDataURL('image/jpeg', OUTPUT_QUALITY);
    savedB64  = b64;

    try {
        // FormData instead of JSON — avoids ModSecurity blocks on free hosting
        const fd = new FormData();
        fd.append('student_id', studentData.id);
        fd.append('photo_data', b64);
        fd.append('_token',     csrfToken);

        const res = await fetch(API_SAVE, { method: 'POST', body: fd });
        const raw = await res.text();

        let data;
        try {
            data = JSON.parse(raw);
        } catch {
            console.error('Raw server response:', raw);
            showAlert(null, 'error', 'Server error. Open the console (F12) for details.');
            return;
        }

        if (data.success) goStep3();
        else showAlert(null, 'error', data.message || 'Upload failed. Please try again.');

    } catch (fetchErr) {
        console.error('Fetch error:', fetchErr);
        showAlert(null, 'error', 'Network error: ' + fetchErr.message);
    } finally {
        setLoading(btn, false, '<i class="bi bi-check-lg"></i> Use This Photo');
    }
}

// ── STEP 3: SUCCESS ───────────────────────────────────────
function goStep3() {
    const ring = document.getElementById('successRing');
    const chk  = document.getElementById('successCheck');
    if (savedB64) {
        document.getElementById('successImg').src = savedB64;
        ring.style.display = 'block';
        chk.style.display  = 'none';
    }
    setStep(3);
    showIsland(studentData?.name ?? 'Student', 'Photo saved successfully', 'success', savedB64);
}

// ── DYNAMIC ISLAND ────────────────────────────────────────
let _it1, _it2, _it3;

function showIsland(title, msg, type = 'success', photoB64 = null) {
    const island  = document.getElementById('dIsland');
    const bar     = document.getElementById('diBar');
    const diImg   = document.getElementById('diPhotoImg');
    const diInit  = document.getElementById('diInitials');
    const diChk   = document.getElementById('diCheck');

    clearTimeout(_it1); clearTimeout(_it2); clearTimeout(_it3);
    bar.classList.remove('draining');
    island.classList.remove('visible', 'expanded', 'type-success', 'type-error', 'type-warning');
    void island.offsetWidth; // force reflow

    document.getElementById('diTitle').textContent = title;
    document.getElementById('diSub').textContent   = msg;

    // Set icon and color type
    if (type === 'error') {
        diChk.textContent = '✕';
        island.classList.add('type-error');
        diInit.style.display = 'flex';
        diInit.textContent   = '!';
        diImg.style.display  = 'none';
    } else if (type === 'warning') {
        diChk.textContent = '!';
        island.classList.add('type-warning');
        diInit.style.display = 'flex';
        diInit.textContent   = '!';
        diImg.style.display  = 'none';
    } else {
        diChk.textContent = '✓';
        island.classList.add('type-success');
        if (photoB64) {
            diImg.src            = photoB64;
            diImg.style.display  = 'block';
            diInit.style.display = 'none';
        } else {
            diImg.style.display  = 'none';
            diInit.style.display = 'flex';
            diInit.textContent   = title.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
        }
    }

    // errors/warnings stay a bit longer
    const duration = type === 'warning' ? 7000 : type === 'error' ? 5500 : 4300;

    requestAnimationFrame(() => {
        island.classList.add('visible');
        _it1 = setTimeout(() => {
            island.classList.add('expanded');
            _it2 = setTimeout(() => bar.classList.add('draining'), 550);
            _it3 = setTimeout(() => {
                island.classList.remove('expanded');
                setTimeout(() => island.classList.remove(
                    'visible', 'type-success', 'type-error', 'type-warning'
                ), 480);
            }, duration);
        }, 80);
    });
}

// ── UNIFIED ALERT → ISLAND ────────────────────────────────
function showAlert(id, type, msg) {
    const titles = { error: 'Error', warning: 'Warning', success: 'Success' };
    showIsland(titles[type] ?? 'Notice', msg, type);
}

function hideAlert(id) {
    // Island auto-hides — no-op kept so existing calls don't break
}

// ── RESET ─────────────────────────────────────────────────
function resetAll() {
    if (cropper) { cropper.destroy(); cropper = null; }
    studentData = null;
    savedB64    = null;
    document.getElementById('inputStudentNo').value         = '';
    document.getElementById('inputLastName').value          = '';
    document.getElementById('paneUpload').style.display     = 'block';
    document.getElementById('paneCamera').style.display     = 'none';
    document.getElementById('cropSection').style.display    = 'none';
    document.getElementById('photoFile').value              = '';
    document.getElementById('successRing').style.display    = 'none';
    document.getElementById('successCheck').style.display   = 'flex';
    stopCamera();
    switchTab('upload');
    setStep(1);
}

// ── HELPERS ───────────────────────────────────────────────
function setStep(n) {
    [1, 2, 3].forEach(i => {
        document.getElementById(`panel-${i}`).classList.toggle('active', i === n);
        const dot = document.getElementById(`dot-${i}`);
        dot.classList.remove('active', 'done');
        if (i < n) {
            dot.classList.add('done');
            dot.querySelector('.step-num').innerHTML = '<i class="bi bi-check-lg"></i>';
        } else if (i === n) {
            dot.classList.add('active');
            dot.querySelector('.step-num').textContent = i;
        } else {
            dot.querySelector('.step-num').textContent = i;
        }
    });
}

function setLoading(btn, loading, label) {
    btn.disabled  = loading;
    btn.innerHTML = loading
        ? '<span class="spinner"></span> ' + label
        : label;
}

function enc(v) { return encodeURIComponent(v); }

// ── TAB SWITCHER ─────────────────────────────────────────
function switchTab(tab) {
    const isCamera = tab === 'camera';
    document.getElementById('tabUpload').classList.toggle('active', !isCamera);
    document.getElementById('tabCamera').classList.toggle('active', isCamera);
    if (document.getElementById('cropSection').style.display === 'none') {
        document.getElementById('paneUpload').style.display = isCamera ? 'none' : 'block';
        document.getElementById('paneCamera').style.display = isCamera ? 'block' : 'none';
    }
    if (!isCamera) stopCamera();
}

// ── CAMERA ────────────────────────────────────────────────
let camStream = null;

async function toggleCamera() {
    if (camStream) { stopCamera(); return; }

    const btn  = document.getElementById('btnCamToggle');
    const lbl  = document.getElementById('camToggleLabel');
    const icon = document.getElementById('camToggleIcon');
    btn.disabled   = true;
    lbl.textContent = 'Starting…';

    try {
        camStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 } }
        });
        const video = document.getElementById('camVideo');
        video.srcObject    = camStream;
        video.style.display = 'block';
        document.getElementById('camPlaceholder').style.display = 'none';
        document.getElementById('camGuide').style.display       = 'flex';
        document.getElementById('btnCapture').disabled          = false;
        icon.className  = 'bi bi-camera-video-off';
        lbl.textContent = 'Stop Camera';
    } catch (e) {
        let msg = 'Camera error: ';
        if      (e.name === 'NotAllowedError') msg += 'Permission denied.';
        else if (e.name === 'NotFoundError')   msg += 'No camera found.';
        else                                   msg += e.message;
        showAlert(null, 'error', msg);
        camStream      = null;
        icon.className = 'bi bi-camera-video';
        lbl.textContent = 'Start Camera';
    } finally {
        btn.disabled = false;
    }
}

function stopCamera() {
    if (camStream) { camStream.getTracks().forEach(t => t.stop()); camStream = null; }
    const video       = document.getElementById('camVideo');
    const placeholder = document.getElementById('camPlaceholder');
    const guide       = document.getElementById('camGuide');
    const capture     = document.getElementById('btnCapture');
    const icon        = document.getElementById('camToggleIcon');
    const lbl         = document.getElementById('camToggleLabel');
    if (video)       { video.srcObject = null; video.style.display = 'none'; }
    if (placeholder)   placeholder.style.display = 'flex';
    if (guide)         guide.style.display        = 'none';
    if (capture)       capture.disabled           = true;
    if (icon)          icon.className             = 'bi bi-camera-video';
    if (lbl)           lbl.textContent            = 'Start Camera';
}

function capturePhoto() {
    const video = document.getElementById('camVideo');
    if (!video || !camStream) return;

    const flash = document.getElementById('camFlash');
    flash.classList.add('on');
    setTimeout(() => flash.classList.remove('on'), 150);

    const canvas = document.createElement('canvas');
    canvas.width  = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx.translate(canvas.width, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0);

    stopCamera();
    initCropper(canvas.toDataURL('image/jpeg', 0.92));
}

// ── DRAG & DROP ───────────────────────────────────────────
const dz = document.getElementById('dropZone');
dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('over'); });
dz.addEventListener('dragleave', () => dz.classList.remove('over'));
dz.addEventListener('drop', e => {
    e.preventDefault();
    dz.classList.remove('over');
    const file = e.dataTransfer.files[0];
    if (file) {
        const dt = new DataTransfer();
        dt.items.add(file);
        document.getElementById('photoFile').files = dt.files;
        handleFile(document.getElementById('photoFile'));
    }
});