// ========================================
// PROFILE — FACE RECOGNITION ENROLMENT
// ========================================
//
// Lets a signed-in user add a face if they never enrolled one, replace the
// one they have, or drop it entirely.
//
// This does NOT reuse assets/js/faceRecognition.js. That file is the
// registration flow's UI as much as its logic — showFacePreview() and
// removeFacePreview() write inline styles straight onto reg.php's preview
// panel, and its top-level code binds #enableFaceRecognition and
// #registerForm on load. Sharing it would have meant either importing
// reg.php's markup into this page, against the design system, or gutting a
// flow that works today. The capture contract is what actually matters and
// it is small: five descriptors, 128 floats each, JSON.stringify'd into a
// hidden field, which is exactly the shape crud/reg_process.php writes and
// crud/get_face_users.php serves back.
//
// Nothing here writes to the database. The descriptor is staged in a hidden
// input inside #profileForm and goes up with everything else when the user
// presses Save Changes — same as the avatar.

(function () {
    'use strict';

    const card = document.getElementById('faceEnroll');
    if (!card) return; // not the profile page

    const MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/';
    const TOTAL_CAPTURES = 5;
    const CAPTURE_DELAY = 800;

    const badge = document.getElementById('faceEnrollBadge');
    const note = document.getElementById('faceEnrollNote');
    const enrollBtn = document.getElementById('faceEnrollBtn');
    const enrollBtnText = document.getElementById('faceEnrollBtnText');
    const removeBtn = document.getElementById('faceRemoveBtn');
    const descriptorField = document.getElementById('faceDescriptorField');
    const removeField = document.getElementById('removeFaceField');

    const modal = document.getElementById('pfFaceModal');
    const dialogTitle = document.getElementById('pfFaceTitleText');
    const video = document.getElementById('pfFaceVideo');
    const canvas = document.getElementById('pfFaceCanvas');
    const pips = document.getElementById('pfFacePips');
    const statusEl = document.getElementById('pfFaceStatus');
    const captureBtn = document.getElementById('pfFaceCapture');
    const cancelBtn = document.getElementById('pfFaceCancel');
    const closeBtn = document.getElementById('pfFaceClose');

    // Whether the SERVER currently holds a face. Only the page load and a
    // successful save change this.
    let enrolledOnServer = card.dataset.enrolled === '1';
    // What the user has staged but not yet saved: 'capture', 'remove', or null.
    let pending = null;

    let modelsReady = false;
    let stream = null;
    let detectTimer = null;
    let captured = [];
    let liveDescriptor = null;
    let busy = false;
    let statusLocked = false;

    // ── Card ────────────────────────────────────────────────────

    function renderCard() {
        pips.innerHTML = '';

        if (pending === 'capture') {
            badge.textContent = 'New face ready';
            badge.className = 'face-enroll-badge is-pending';
            note.textContent = 'Press Save Changes to store it.';
        } else if (pending === 'remove') {
            badge.textContent = 'Will be removed';
            badge.className = 'face-enroll-badge is-pending';
            note.textContent = 'Press Save Changes to confirm.';
        } else if (enrolledOnServer) {
            badge.textContent = 'Enabled';
            badge.className = 'face-enroll-badge is-on';
            note.textContent = 'You can sign in with your face.';
        } else {
            badge.textContent = 'Not set up';
            badge.className = 'face-enroll-badge is-off';
            note.textContent = 'Add your face to sign in without a password.';
        }

        enrollBtnText.textContent = (enrolledOnServer || pending === 'capture') ? 'Update' : 'Set up';
        // Nothing to remove when the server has none and none is staged.
        removeBtn.hidden = !enrolledOnServer && pending !== 'capture';
        card.dataset.enrolled = enrolledOnServer ? '1' : '0';
    }

    // ── Modal plumbing ──────────────────────────────────────────

    function drawPips() {
        pips.innerHTML = '';
        for (let i = 0; i < TOTAL_CAPTURES; i++) {
            const d = document.createElement('span');
            d.className = 'pf-face-pip' + (i < captured.length ? ' is-done' : '');
            pips.appendChild(d);
        }
    }

    /* The detector loop rewrites the status line several times a second, so
       anything written from outside it needs to say so or it is gone before
       it can be read — which is exactly what happened to the "already
       registered" warning. setStatus(..., true) holds a message until the
       user does something that means they have seen it: pressing Capture, or
       reopening the dialog. */
    function setStatus(text, kind, hold) {
        statusEl.textContent = text;
        statusEl.className = 'pf-face-status' + (kind ? ' is-' + kind : '');
        if (hold) statusLocked = true;
    }

    // What the detector uses. Never overwrites a held message.
    function setLiveStatus(text, kind) {
        if (statusLocked) return;
        setStatus(text, kind);
    }

    async function openModal() {
        captured = [];
        liveDescriptor = null;
        busy = false;
        statusLocked = false; // fresh session, nothing to hold on screen
        modal.hidden = false;
        document.body.style.overflow = 'hidden';
        dialogTitle.textContent = (enrolledOnServer || pending === 'capture')
            ? 'Update face recognition'
            : 'Set up face recognition';
        captureBtn.disabled = true;
        drawPips();

        try {
            if (!modelsReady) {
                setStatus('Loading face models…');
                await Promise.all([
                    faceapi.nets.tinyFaceDetector.loadFromUri(MODEL_URL),
                    faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
                    faceapi.nets.faceRecognitionNet.loadFromUri(MODEL_URL)
                ]);
                modelsReady = true;
            }

            setStatus('Starting camera…');
            stream = await navigator.mediaDevices.getUserMedia({
                video: { width: 640, height: 480, facingMode: 'user' }
            });
            video.srcObject = stream;
            await video.play().catch(() => { });

            canvas.width = video.videoWidth || 640;
            canvas.height = video.videoHeight || 480;

            setStatus('Look at the camera.');
            // Self-scheduling rather than setInterval: a detect pass on a
            // slow machine can outrun a fixed tick, and stacked passes only
            // make it slower.
            const loop = async () => {
                await detectOnce();
                if (stream) detectTimer = setTimeout(loop, 150);
            };
            loop();
        } catch (err) {
            console.error(err);
            setStatus(
                err && err.name === 'NotAllowedError'
                    ? 'Camera permission was denied. Allow it in the browser, then try again.'
                    : 'Could not start the camera. ' + (err && err.message ? err.message : ''),
                'bad',
                true
            );
        }
    }

    function closeModal() {
        if (detectTimer) { clearTimeout(detectTimer); detectTimer = null; }
        if (stream) {
            stream.getTracks().forEach(t => t.stop());
            stream = null;
        }
        video.srcObject = null;
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        modal.hidden = true;
        document.body.style.overflow = '';
    }

    // ── Detection ───────────────────────────────────────────────

    async function detectOnce() {
        if (busy || !stream) return;

        const detection = await faceapi
            .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions({ inputSize: 320, scoreThreshold: 0.5 }))
            .withFaceLandmarks()
            .withFaceDescriptor();

        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        if (!detection) {
            liveDescriptor = null;
            if (captured.length === 0) captureBtn.disabled = true;
            setLiveStatus('Looking for a face…');
            return;
        }

        const resized = faceapi.resizeResults(detection, {
            width: canvas.width,
            height: canvas.height
        });
        const box = resized.detection.box;

        // The preview is mirrored, so the overlay is drawn mirrored to match.
        ctx.save();
        ctx.scale(-1, 1);
        ctx.translate(-canvas.width, 0);
        ctx.strokeStyle = '#38bdf8';
        ctx.lineWidth = 3;
        ctx.lineCap = 'round';
        const arm = Math.max(16, Math.min(box.width, box.height) * 0.22);
        [[box.x, box.y, 1, 1],
        [box.x + box.width, box.y, -1, 1],
        [box.x, box.y + box.height, 1, -1],
        [box.x + box.width, box.y + box.height, -1, -1]].forEach(([cx, cy, dx, dy]) => {
            ctx.beginPath();
            ctx.moveTo(cx + dx * arm, cy);
            ctx.lineTo(cx, cy);
            ctx.lineTo(cx, cy + dy * arm);
            ctx.stroke();
        });
        ctx.restore();

        liveDescriptor = detection.descriptor;
        captureBtn.disabled = false;
        setLiveStatus(
            captured.length === 0
                ? 'Face detected. Press Capture.'
                : `Captured ${captured.length} of ${TOTAL_CAPTURES}. Keep looking at the camera.`,
            'ok'
        );
    }

    // ── Capture ─────────────────────────────────────────────────

    async function runCapture() {
        if (busy || !liveDescriptor) return;
        busy = true;
        // Pressing Capture is the user acknowledging whatever was held on the
        // status line, so the detector may write to it again.
        statusLocked = false;
        captureBtn.disabled = true;

        for (let i = captured.length; i < TOTAL_CAPTURES; i++) {
            if (!liveDescriptor) {
                setStatus('Lost your face — line up again and press Capture.', 'bad', true);
                busy = false;
                return;
            }
            captured.push(Array.from(liveDescriptor));
            drawPips();
            setStatus(`Captured ${captured.length} of ${TOTAL_CAPTURES}. Hold still…`, 'ok');
            if (captured.length < TOTAL_CAPTURES) {
                await new Promise(r => setTimeout(r, CAPTURE_DELAY));
                await detectOnce();
            }
        }

        setStatus('Checking that this face is not already registered…');

        try {
            const res = await fetch('../crud/check_face_duplicate.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                // excludeSelf: without it the closest match is your OWN stored
                // face and every re-enrolment would be rejected as a duplicate
                // of yourself. The endpoint takes the id from the session, not
                // from here.
                body: JSON.stringify({ descriptor: captured[0], excludeSelf: true })
            });
            const data = await res.json();

            if (data && data.isDuplicate) {
                setStatus(
                    data.userName
                        ? `This face is already registered to ${data.userName}. Nothing was saved.`
                        : 'This face is already registered to another account. Nothing was saved.',
                    'bad',
                    true // hold it — the detector would wipe it in ~150ms
                );
                captured = [];
                drawPips();
                busy = false;
                return;
            }
        } catch (err) {
            // A failed check must not silently pass as "unique" — the server
            // revalidates the shape but does not re-run the duplicate test.
            console.error(err);
            setStatus('Could not check this face against existing accounts. Nothing was saved — try again.', 'bad', true);
            captured = [];
            drawPips();
            busy = false;
            return;
        }

        descriptorField.value = JSON.stringify(captured);
        removeField.value = '0';
        pending = 'capture';
        renderCard();
        closeModal();

        if (window.Swal) {
            Swal.fire({
                icon: 'success',
                title: 'Face captured',
                text: 'Press Save Changes to store it on your account.',
                timer: 2200,
                showConfirmButton: false
            });
        }
    }

    // ── Wiring ──────────────────────────────────────────────────

    enrollBtn.addEventListener('click', () => {
        if (typeof faceapi === 'undefined') {
            setStatus('Face library is still loading. Try again in a moment.', 'bad');
            modal.hidden = false;
            return;
        }
        openModal();
    });

    captureBtn.addEventListener('click', runCapture);
    cancelBtn.addEventListener('click', closeModal);
    closeBtn.addEventListener('click', closeModal);
    modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });
    document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && !modal.hidden) closeModal();
    });

    removeBtn.addEventListener('click', () => {
        if (pending === 'capture') {
            // Undo the staged capture rather than queueing a removal of the
            // face that is still on the server.
            descriptorField.value = '';
            removeField.value = '0';
            pending = null;
            renderCard();
            return;
        }
        descriptorField.value = '';
        removeField.value = '1';
        pending = 'remove';
        renderCard();
    });

    // Reset puts the whole form back, so it has to put this back too. The
    // native reset does not touch values set from script.
    const form = document.getElementById('profileForm');
    if (form) {
        form.addEventListener('reset', () => {
            setTimeout(() => {
                descriptorField.value = '';
                removeField.value = '0';
                pending = null;
                renderCard();
            }, 0);
        });
    }

    // After a successful save the staged state has become the real state.
    document.addEventListener('profile:saved', e => {
        const d = e.detail || {};
        if (d.face_changed) enrolledOnServer = !!d.face_enabled;
        descriptorField.value = '';
        removeField.value = '0';
        pending = null;
        renderCard();
    });

    renderCard();
})();
