// ========================================
// FACE LOGIN MODULE - MULTI-DESCRIPTOR VERSION
// Supports both old (1 descriptor) and new (5 descriptors) formats
// ========================================
let loginModelsLoaded = false;
let loginStream = null;
let loginDetectionInterval = null;
let registeredUsers = [];

const loginVideo = document.getElementById('loginFaceVideo');
const loginCanvas = document.getElementById('loginFaceCanvas');
const faceVideoWrapper = document.getElementById('faceVideoWrapper');
const faceLoginStatus = document.getElementById('faceLoginStatus');

// ========================================
// TEXT-TO-SPEECH FUNCTIONALITY
// ========================================
let ttsEnabled = true;
let lastSpokenText = '';
let isSpeaking = false;

async function speak(text, force = false) {
    if (!ttsEnabled) return;

    if (isSpeaking && !force) return;

    if (force && isSpeaking) {
        window.speechSynthesis.cancel();
        isSpeaking = false;
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    while (isSpeaking) {
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    return new Promise((resolve) => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.rate = 1.0;
        utterance.pitch = 1.0;
        utterance.volume = 1.0;
        utterance.lang = 'en-US';

        utterance.onstart = () => {
            isSpeaking = true;
            console.log(`Speaking: "${text}"`);
        };

        utterance.onend = () => {
            isSpeaking = false;
            lastSpokenText = text;
            window.speechSynthesis.cancel();
            resolve();
        };

        utterance.onerror = () => {
            isSpeaking = false;
            window.speechSynthesis.cancel();
            resolve();
        };

        window.speechSynthesis.cancel();
        window.speechSynthesis.speak(utterance);
    });
}

function toggleTTS() {
    ttsEnabled = !ttsEnabled;
    if (!ttsEnabled) {
        window.speechSynthesis.cancel();
        isSpeaking = false;
    }
    return ttsEnabled;
}

// ========================================
// DRAW NAME LABEL ON CANVAS
// ========================================
/* The overlay palette is pinned rather than read from the theme tokens, and
   that is deliberate. --scan-ink/--ok-ink/--bad-ink flip to dark inks in the
   light theme (#0369a1, #047857, #b91c1c) because they are meant for text on a
   light surface. The camera preview is not a light surface — login.css holds
   .face-video-wrapper-modal at #0b1220 in BOTH themes on purpose, since a white
   frame around a live face is glare. So the overlay always sits on near-black
   and always wants the bright variants.

   The three hues below are the same ones .face-login-status-modal already uses
   for its detecting/success/error chips (sky 56,189,248 · emerald 16,185,129 ·
   red 239,68,68). Previously the canvas drew Material colours — #2196f3,
   #4caf50, #f44336 — so the box around the face never quite matched the status
   bar directly beneath it. Now they agree. */
const FACE_OVERLAY_COLORS = {
    detecting: { bg: '#38bdf8', text: '#04263a' },
    success: { bg: '#10b981', text: '#03251b' },
    error: { bg: '#ef4444', text: '#2a0606' }
};

function drawNameLabel(ctx, box, name, status = 'detecting') {
    const color = FACE_OVERLAY_COLORS[status] || FACE_OVERLAY_COLORS.detecting;

    ctx.font = 'bold 18px Arial, sans-serif';
    const textMetrics = ctx.measureText(name);
    const textWidth = textMetrics.width;
    const textHeight = 24;
    const padding = 12;

    const labelWidth = textWidth + (padding * 2);
    const labelHeight = textHeight + (padding * 1.5);
    const labelX = box.x + (box.width / 2) - (labelWidth / 2);
    const labelY = box.y - labelHeight - 10;

    ctx.fillStyle = color.bg;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
    ctx.shadowBlur = 10;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 2;

    const radius = 8;
    ctx.beginPath();
    ctx.moveTo(labelX + radius, labelY);
    ctx.lineTo(labelX + labelWidth - radius, labelY);
    ctx.quadraticCurveTo(labelX + labelWidth, labelY, labelX + labelWidth, labelY + radius);
    ctx.lineTo(labelX + labelWidth, labelY + labelHeight - radius);
    ctx.quadraticCurveTo(labelX + labelWidth, labelY + labelHeight, labelX + labelWidth - radius, labelY + labelHeight);
    ctx.lineTo(labelX + radius, labelY + labelHeight);
    ctx.quadraticCurveTo(labelX, labelY + labelHeight, labelX, labelY + labelHeight - radius);
    ctx.lineTo(labelX, labelY + radius);
    ctx.quadraticCurveTo(labelX, labelY, labelX + radius, labelY);
    ctx.closePath();
    ctx.fill();

    ctx.shadowColor = 'transparent';
    ctx.shadowBlur = 0;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 0;

    /* The caller draws under ctx.scale(-1, 1) so the overlay lines up with the
       mirrored selfie video. A rectangle survives that flip unchanged, but text
       does not — the name rendered back-to-front on screen. Flipping a second
       time around the label's own centre restores normal reading order while
       leaving the label positioned over the face. */
    ctx.save();
    ctx.translate(labelX + labelWidth / 2, labelY + labelHeight / 2);
    ctx.scale(-1, 1);

    ctx.fillStyle = color.text;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(name, 0, 0);

    ctx.restore();
}

/* Corner brackets instead of a closed rectangle. A full box reads as a crop
   frame and fights the face inside it; brackets read as a reticle, which is
   also what the QR scanner elsewhere in the system uses — same visual language
   for "the camera is locked onto something".

   `progress` (0..1) fills the bottom edge as the consecutive-match count
   climbs, so the 1/3 → 3/3 countdown is visible on the video itself instead of
   only as text in the status bar below. */
function drawDetectionFrame(ctx, box, status = 'detecting', progress = 0) {
    const color = (FACE_OVERLAY_COLORS[status] || FACE_OVERLAY_COLORS.detecting).bg;
    const arm = Math.max(18, Math.min(box.width, box.height) * 0.22);
    const r = 10;

    ctx.save();
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    const corners = [
        [box.x, box.y, 1, 1],
        [box.x + box.width, box.y, -1, 1],
        [box.x, box.y + box.height, 1, -1],
        [box.x + box.width, box.y + box.height, -1, -1]
    ];

    for (const [cx, cy, dx, dy] of corners) {
        ctx.beginPath();
        ctx.moveTo(cx + dx * arm, cy);
        ctx.lineTo(cx + dx * r, cy);
        ctx.quadraticCurveTo(cx, cy, cx, cy + dy * r);
        ctx.lineTo(cx, cy + dy * arm);
        ctx.stroke();
    }

    if (progress > 0) {
        const clamped = Math.max(0, Math.min(1, progress));
        const span = box.width * 0.5 * clamped;
        const midX = box.x + box.width / 2;
        const y = box.y + box.height;

        ctx.globalAlpha = 0.9;
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(midX - span, y);
        ctx.lineTo(midX + span, y);
        ctx.stroke();
    }

    ctx.restore();
}

// ========================================
// LOAD FACE-API MODELS
// ========================================
async function loadLoginModels() {
    if (loginModelsLoaded) return true;

    try {
        const MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/';

        faceLoginStatus.textContent = 'Loading AI models...';
        faceLoginStatus.className = 'face-login-status-modal';
        /* Not awaited — this sat directly in front of the download, so the
           7 MB of weights did not begin transferring until the sentence had
           finished being spoken. */
        speak('Loading AI models', true);

        await Promise.all([
            faceapi.nets.tinyFaceDetector.loadFromUri(MODEL_URL),
            faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
            faceapi.nets.faceRecognitionNet.loadFromUri(MODEL_URL)
        ]);

        loginModelsLoaded = true;
        console.log('Models loaded successfully');
        speak('Models loaded successfully', true);
        return true;
    } catch (error) {
        console.error('Error loading models:', error);
        faceLoginStatus.textContent = 'Error loading AI models. Please try password login.';
        faceLoginStatus.className = 'face-login-status-modal error';
        await speak('Error loading AI models. Please try password login.', true);
        return false;
    }
}

// ========================================
// FETCH REGISTERED USERS - MULTI-DESCRIPTOR SUPPORT
// ========================================
async function fetchRegisteredUsers() {
    try {
        const response = await fetch('crud/get_face_users.php');
        const data = await response.json();

        console.log('=== API Response ===');
        console.log('Success:', data.success);
        console.log('User count:', data.count);

        if (data.success) {
            registeredUsers = data.users.map(user => {
                const parsedData = JSON.parse(user.face_descriptor);
                
                // Check if multi-descriptor format (array of arrays)
                const isMultiDescriptor = Array.isArray(parsedData[0]);
                
                if (isMultiDescriptor) {
                    // Multiple descriptors (5 images)
                    const descriptors = parsedData.map(desc => new Float32Array(desc));
                    
                    console.log(`\nUser: ${user.name} (MULTI-DESCRIPTOR)`);
                    console.log('  - Total descriptors:', descriptors.length);
                    descriptors.forEach((desc, i) => {
                        console.log(`  - Descriptor ${i+1} length:`, desc.length);
                    });
                    
                    return {
                        id: user.id,
                        name: user.name,
                        email: user.email,
                        descriptors: descriptors, // Array of Float32Array
                        isMulti: true
                    };
                } else {
                    // Single descriptor (1 image - old format)
                    const descriptor = new Float32Array(parsedData);
                    
                    console.log(`\nUser: ${user.name} (SINGLE-DESCRIPTOR - OLD FORMAT)`);
                    console.log('  - Descriptor length:', descriptor.length);
                    
                    return {
                        id: user.id,
                        name: user.name,
                        email: user.email,
                        descriptors: [descriptor], // Wrap in array for consistency
                        isMulti: false
                    };
                }
            });

            console.log(`\nLoaded ${registeredUsers.length} users total`);
            const multiCount = registeredUsers.filter(u => u.isMulti).length;
            const singleCount = registeredUsers.filter(u => !u.isMulti).length;
            console.log(`   - Multi-descriptor users: ${multiCount}`);
            console.log(`   - Single-descriptor users: ${singleCount}`);
            
            return true;
        } else {
            throw new Error(data.message || 'Failed to fetch users');
        }
    } catch (error) {
        console.error('Error fetching users:', error);
        faceLoginStatus.textContent = 'Error loading user data. Please try password login.';
        faceLoginStatus.className = 'face-login-status-modal error';
        await speak('Error loading user data. Please try password login.', true);
        return false;
    }
}

// ========================================
// START CAMERA
// ========================================
async function startLoginCamera() {
    try {
        loginStream = await navigator.mediaDevices.getUserMedia({
            video: {
                width: { ideal: 640 },
                height: { ideal: 480 },
                facingMode: 'user'
            }
        });

        loginVideo.srcObject = loginStream;
        loginVideo.style.transform = 'scaleX(-1)';

        if (typeof initializeFlashlight === 'function') {
            await initializeFlashlight(loginStream);
        }

        return new Promise((resolve) => {
            loginVideo.onloadedmetadata = async () => {
                loginCanvas.width = loginVideo.videoWidth;
                loginCanvas.height = loginVideo.videoHeight;
                console.log('Camera started');
                /* Not awaited: this promise is what startFaceLogin's
                   Promise.all waits on, so awaiting the announcement here
                   would hold the whole parallel group open until it finished
                   speaking — reintroducing the delay the group removes. */
                speak('Camera started', true);
                resolve(true);
            };
        });
    } catch (error) {
        console.error('Camera error:', error);
        faceLoginStatus.textContent = 'Camera access denied. Please enable camera or use password login.';
        faceLoginStatus.className = 'face-login-status-modal error';
        await speak('Camera access denied. Please enable camera or use password login.', true);
        return false;
    }
}

// ========================================
// STOP CAMERA
// ========================================
function stopFaceLogin() {
    if (loginDetectionInterval) {
        clearTimeout(loginDetectionInterval);
        loginDetectionInterval = null;
    }

    if (loginStream) {
        loginStream.getTracks().forEach(track => track.stop());
        loginStream = null;
    }

    window.speechSynthesis.cancel();

    isProcessingLogin = false;
    consecutiveMatches = 0;
    lastMatchedUserId = null;

    if (loginCanvas) {
        const ctx = loginCanvas.getContext('2d');
        ctx.clearRect(0, 0, loginCanvas.width, loginCanvas.height);
        loginCanvas.width = loginCanvas.width;
    }

    if (loginVideo) {
        loginVideo.srcObject = null;
    }

    faceLoginStatus.textContent = 'Initializing face recognition...';
    faceLoginStatus.className = 'face-login-status-modal';

    console.log('Face login stopped and cleaned up');
}

// ========================================
// COMPARE FACES - MULTI-DESCRIPTOR VERSION
// Compares against ALL stored descriptors, returns minimum distance
// ========================================
function findMatchingUser(currentDescriptor) {
    const MATCH_THRESHOLD = 0.45;

    if (!currentDescriptor || currentDescriptor.length !== 128) {
        console.error('Invalid current descriptor');
        return null;
    }

    if (currentDescriptor.some(v => isNaN(v))) {
        console.error('Current descriptor contains NaN');
        return null;
    }

    console.log('\n=== FACE MATCHING ANALYSIS (MULTI-DESCRIPTOR) ===');

    let bestMatch = null;
    let bestDistance = Infinity;
    let allDistances = [];

    for (const user of registeredUsers) {
        if (!user.descriptors || user.descriptors.length === 0) {
            console.warn(`No descriptors for user ${user.name}`);
            continue;
        }

        // Compare against ALL descriptors for this user, get minimum
        let minDistanceForUser = Infinity;
        let bestDescriptorIndex = -1;

        user.descriptors.forEach((storedDesc, index) => {
            if (!storedDesc || storedDesc.length !== 128) {
                console.warn(`Invalid descriptor ${index} for user ${user.name}`);
                return;
            }

            if (storedDesc.some(v => isNaN(v))) {
                console.warn(`Descriptor ${index} contains NaN for user ${user.name}`);
                return;
            }

            try {
                const distance = faceapi.euclideanDistance(currentDescriptor, storedDesc);
                
                if (distance < minDistanceForUser) {
                    minDistanceForUser = distance;
                    bestDescriptorIndex = index;
                }
            } catch (error) {
                console.error(`Error comparing descriptor ${index} for ${user.name}:`, error);
            }
        });

        // Use the BEST match from all descriptors
        const matchStatus = minDistanceForUser < MATCH_THRESHOLD ? 'MATCH' : 'NO MATCH';
        const descriptorInfo = user.isMulti ? `[${user.descriptors.length} descriptors, best: #${bestDescriptorIndex + 1}]` : '[1 descriptor]';
        
        console.log(`${user.name} ${descriptorInfo}: ${minDistanceForUser.toFixed(4)} ${matchStatus}`);
        
        allDistances.push({ name: user.name, distance: minDistanceForUser });

        if (minDistanceForUser < MATCH_THRESHOLD && minDistanceForUser < bestDistance) {
            bestDistance = minDistanceForUser;
            bestMatch = user;
        }
    }

    console.log(`\nTHRESHOLD: ${MATCH_THRESHOLD}`);
    if (bestMatch) {
        console.log(`BEST MATCH: ${bestMatch.name} (distance: ${bestDistance.toFixed(4)})`);
        console.log(`Confidence: ${((1 - bestDistance) * 100).toFixed(1)}%`);
        console.log(`Format: ${bestMatch.isMulti ? 'Multi-descriptor (5 images)' : 'Single-descriptor (1 image)'}`);
    } else {
        console.log('NO MATCH FOUND');
        if (allDistances.length > 0) {
            const closest = allDistances.sort((a, b) => a.distance - b.distance)[0];
            console.log(`   Closest was ${closest.name} at ${closest.distance.toFixed(4)} (above threshold)`);
        }
    }
    console.log('================================================\n');

    return bestMatch;
}

// ========================================
// DETECT AND MATCH FACE
// ========================================
let isProcessingLogin = false;
let consecutiveMatches = 0;
let lastMatchedUserId = null;
const REQUIRED_CONSECUTIVE_MATCHES = 3;
let lastSpokenName = null;

async function detectAndMatchFace() {
    if (isProcessingLogin) return;

    const detectionOptions = new faceapi.TinyFaceDetectorOptions({
        inputSize: 416,
        scoreThreshold: 0.5
    });

    const detection = await faceapi
        .detectSingleFace(loginVideo, detectionOptions)
        .withFaceLandmarks()
        .withFaceDescriptor();

    const ctx = loginCanvas.getContext('2d');
    ctx.clearRect(0, 0, loginCanvas.width, loginCanvas.height);

    ctx.save();
    ctx.scale(-1, 1);
    ctx.translate(-loginCanvas.width, 0);

    if (detection) {
        console.log(`\nFace detected (confidence: ${(detection.detection.score * 100).toFixed(1)}%)`);

        const resizedDetection = faceapi.resizeResults(detection, {
            width: loginCanvas.width,
            height: loginCanvas.height
        });

        const matchedUser = findMatchingUser(detection.descriptor);
        const box = resizedDetection.detection.box;

        if (matchedUser) {
            if (lastMatchedUserId === matchedUser.id) {
                consecutiveMatches++;
            } else {
                consecutiveMatches = 1;
                lastMatchedUserId = matchedUser.id;
            }

            console.log(`Consecutive matches: ${consecutiveMatches}/${REQUIRED_CONSECUTIVE_MATCHES}`);

            if (consecutiveMatches >= REQUIRED_CONSECUTIVE_MATCHES) {
                isProcessingLogin = true;

                if (loginDetectionInterval) {
                    clearTimeout(loginDetectionInterval);
                    loginDetectionInterval = null;
                }

                drawDetectionFrame(ctx, box, 'success', 1);

                const landmarks = resizedDetection.landmarks.positions;
                ctx.fillStyle = FACE_OVERLAY_COLORS.success.bg;
                landmarks.forEach(point => {
                    ctx.beginPath();
                    ctx.arc(point.x, point.y, 2, 0, 2 * Math.PI);
                    ctx.fill();
                });

                drawNameLabel(ctx, box, matchedUser.name, 'success');

                faceLoginStatus.textContent = `Identity confirmed! Logging in as ${matchedUser.name}`;
                faceLoginStatus.className = 'face-login-status-modal success';

                console.log(`\nLOGIN CONFIRMED: ${matchedUser.name}\n`);

                await speak(`Identity confirmed! Logging in as ${matchedUser.name}`, true);
                await new Promise(resolve => setTimeout(resolve, 800));

                window.speechSynthesis.cancel();
                isSpeaking = false;

                stopFaceLogin();
                // Pass the live descriptor so the SERVER can re-verify the match.
                await loginWithFace(matchedUser.id, matchedUser.name, detection.descriptor);

                return;

            } else {
                drawDetectionFrame(ctx, box, 'detecting', consecutiveMatches / REQUIRED_CONSECUTIVE_MATCHES);

                drawNameLabel(ctx, box, matchedUser.name, 'detecting');

                faceLoginStatus.textContent = `Verifying ${matchedUser.name}... (${consecutiveMatches}/${REQUIRED_CONSECUTIVE_MATCHES})`;
                faceLoginStatus.className = 'face-login-status-modal detecting';
            }

        } else {
            if (!isSpeaking) {
                speak('Unknown');
                lastSpokenName = 'Unknown';
            }

            consecutiveMatches = 0;
            lastMatchedUserId = null;

            drawDetectionFrame(ctx, box, 'error', 0);

            drawNameLabel(ctx, box, 'Unknown', 'error');

            faceLoginStatus.textContent = 'Face not recognized. Please use password login.';
            faceLoginStatus.className = 'face-login-status-modal error';
        }
    } else {
        consecutiveMatches = 0;
        lastMatchedUserId = null;
        lastSpokenName = null;

        faceLoginStatus.textContent = 'Looking for face... Please face the camera.';
        faceLoginStatus.className = 'face-login-status-modal detecting';
    }

    ctx.restore();
}

// ========================================
// LOGIN WITH FACE
// ========================================
async function loginWithFace(userId, userName, descriptor) {
    try {
        window.speechSynthesis.cancel();
        isSpeaking = false;

        // Send the live face descriptor so the server can re-verify the match.
        const descriptorJson = JSON.stringify(Array.from(descriptor || []));

        const response = await fetch('crud/face_login_process.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `user_id=${encodeURIComponent(userId)}&descriptor=${encodeURIComponent(descriptorJson)}`
        });

        const data = await response.json();

        if (data.success) {
            await Swal.fire({
                icon: 'success',
                title: `Welcome!`,
                html: `<p style="font-size: 20px;">Hi ${userName}!, glad to see you back!</p>`,
                background: '#0f172a',
                color: '#fff',
                timer: 2500,
                timerProgressBar: true,
                showConfirmButton: false,
                allowOutsideClick: false,
                allowEscapeKey: false,
                didOpen: () => {
                    const popup = Swal.getPopup();
                    popup.style.borderRadius = '15px';
                }
            });

            window.location.href = data.redirect || '../bccsasqr/pages/dashboard.php';

        } else {
            await Swal.fire({
                icon: 'error',
                title: 'Login Failed',
                text: data.message || 'An error occurred during login.',
                background: '#0f172a',
                color: '#fff',
                confirmButtonColor: '#667eea'
            });
        }
    } catch (error) {
        console.error('Login error:', error);

        await Swal.fire({
            icon: 'error',
            title: 'Login Error',
            text: 'An error occurred. Please try password login.',
            background: '#0f172a',
            color: '#fff',
            confirmButtonColor: '#667eea'
        });
    }
}

// ========================================
// START FACE LOGIN
// ========================================
async function startFaceLogin() {
    faceLoginStatus.textContent = 'Loading...';
    faceLoginStatus.className = 'face-login-status-modal';
    /* Deliberately not awaited. speak() resolves on utterance.onend, so an
       awaited announcement blocks for as long as it takes to say it out loud —
       measured at 2.8s for this one line, 13.1s across the whole startup path.
       The announcements still play; they just no longer gate the work. Later
       calls pass force:true and cut off whatever is still speaking, which is
       what you want from a status announcement: newest status wins. */
    speak('Starting face login', true);

    console.log('\nStarting face login...\n');

    /* These three are independent: a ~7 MB model download, the descriptor
       fetch (~1.4s against InfinityFree's remote MySQL), and the camera
       permission prompt. Run in sequence the prompt only appeared after the
       download had finished; overlapped, the user grants camera access while
       the models are still streaming in. */
    const [modelsReady, usersLoaded, cameraReady] = await Promise.all([
        loadLoginModels(),
        fetchRegisteredUsers(),
        startLoginCamera()
    ]);

    if (!modelsReady || !usersLoaded || !cameraReady) {
        /* Whichever step failed has already written its own message. Release
           the camera by hand rather than calling stopFaceLogin(), which would
           reset that message back to the placeholder text. */
        if (loginStream) {
            loginStream.getTracks().forEach(track => track.stop());
            loginStream = null;
        }
        return;
    }

    if (registeredUsers.length === 0) {
        faceLoginStatus.textContent = 'No users with face recognition enabled. Please use password login.';
        faceLoginStatus.className = 'face-login-status-modal error';
        /* The camera is already live by the time we get here — it now starts
           alongside the other two steps rather than after them, so bailing out
           has to switch it off or the indicator light stays on. */
        if (loginStream) {
            loginStream.getTracks().forEach(track => track.stop());
            loginStream = null;
        }
        speak('No users with face recognition enabled. Please use password login.', true);
        return;
    }

    faceLoginStatus.textContent = 'Looking for face...';
    faceLoginStatus.className = 'face-login-status-modal detecting';
    speak('Looking for face. Please face the camera.', true);

    console.log('Face login ready - watching for faces...\n');

    /* Self-scheduling instead of setInterval: setInterval does not wait for an
       async callback, so on any device where a pass takes longer than the
       delay — likely on a phone, where a single detect runs several times
       slower than the 101ms measured on a desktop — the callbacks pile up and
       the page degrades further with every tick. Chaining the next pass only
       after the current one returns keeps exactly one detection in flight. */
    const DETECT_DELAY_MS = 500;
    const scheduleDetect = () => {
        loginDetectionInterval = setTimeout(async () => {
            await detectAndMatchFace();
            /* A completed match or a stopped camera nulls the handle; without
               this check the loop would resurrect itself after either. */
            if (loginDetectionInterval !== null) scheduleDetect();
        }, DETECT_DELAY_MS);
    };
    scheduleDetect();
}