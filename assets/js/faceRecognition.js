// ========================================
// FACE RECOGNITION MODULE (5 Images Version)
// ========================================

let modelsLoaded = false;
let stream = null;
let faceDetectionInterval = null;
let currentFaceDescriptor = null;
let capturedDescriptors = []; // Store all 5 descriptors

/* detectFace() runs every 100ms and rewrites faceStatus on every pass, so a
   message written from anywhere else survived about a tenth of a second. The
   "face already registered" warning was the one that mattered: it appeared
   and was gone before it could be read, leaving the user with a green "Face
   detected!" and no idea why nothing had been captured.

   While this is set, the detector still tracks and still draws — it just
   stops writing the status line. Pressing the capture button or reopening
   the modal clears it, because both mean the user has moved on. */
let statusLocked = false;

const TOTAL_CAPTURES = 5; // Number of face images to capture
const CAPTURE_DELAY = 800; // Delay between captures (ms)

const video = document.getElementById('faceVideo');
const canvas = document.getElementById('faceCanvas');
const faceModal = document.getElementById('faceModal');
const closeModalBtn = document.getElementById('closeModal');
const enableFaceToggle = document.getElementById('enableFaceRecognition');
const captureFaceBtn = document.getElementById('captureFaceBtn');
const faceStatus = document.getElementById('faceStatus');
const faceDescriptorInput = document.getElementById('faceDescriptor');

// Preview elements
const facePreview = document.getElementById('facePreview');
const faceIcon = document.getElementById('faceIcon');
const faceDesc = document.getElementById('faceDesc');
const faceStatusBox = document.getElementById('faceStatusBox');
const statusText = faceStatusBox.querySelector('.status-text');

// ========================================
// LOAD FACE-API MODELS
// ========================================
async function loadFaceApiModels() {
    if (modelsLoaded) return true;
    
    try {
        const MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api/model/';
        
        faceStatus.textContent = 'Loading AI models...';
        faceStatus.className = 'face-status';
        
        await Promise.all([
            faceapi.nets.tinyFaceDetector.loadFromUri(MODEL_URL),
            faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
            faceapi.nets.faceRecognitionNet.loadFromUri(MODEL_URL)
        ]);
        
        modelsLoaded = true;
        return true;
    } catch (error) {
        console.error('Error loading models:', error);
        faceStatus.textContent = 'Error loading AI models. Please refresh the page.';
        faceStatus.className = 'face-status error';
        return false;
    }
}

// ========================================
// START CAMERA
// ========================================
async function startCamera() {
    try {
        stream = await navigator.mediaDevices.getUserMedia({
            video: {
                width: { ideal: 640 },
                height: { ideal: 480 },
                facingMode: 'user'
            }
        });
        
        video.srcObject = stream;
        
        return new Promise((resolve) => {
            video.onloadedmetadata = () => {
                video.play();
            };
            
            video.onplaying = () => {
                const rect = video.getBoundingClientRect();
                canvas.width = rect.width;
                canvas.height = rect.height;
                
                console.log('Video dimensions:', video.videoWidth, 'x', video.videoHeight);
                console.log('Canvas dimensions:', canvas.width, 'x', canvas.height);
                
                resolve(true);
            };
        });
    } catch (error) {
        console.error('Error accessing camera:', error);
        faceStatus.textContent = 'Camera access denied. Please enable camera permission.';
        faceStatus.className = 'face-status error';
        return false;
    }
}

// ========================================
// STOP CAMERA
// ========================================
function stopCamera() {
    if (stream) {
        stream.getTracks().forEach(track => track.stop());
        stream = null;
    }
    
    if (faceDetectionInterval) {
        clearInterval(faceDetectionInterval);
        faceDetectionInterval = null;
    }
    
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
}

// ========================================
// DETECT FACE IN REAL-TIME
// ========================================
async function detectFace() {
    const detection = await faceapi
        .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions())
        .withFaceLandmarks()
        .withFaceDescriptor();
    
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    if (detection) {
        ctx.save();
        ctx.scale(-1, 1);
        ctx.translate(-canvas.width, 0);
        
        const resizedDetection = faceapi.resizeResults(detection, {
            width: canvas.width,
            height: canvas.height
        });
        
        // Draw box
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 3;
        const box = resizedDetection.detection.box;
        ctx.strokeRect(box.x, box.y, box.width, box.height);
        
        // Draw landmarks
        ctx.fillStyle = '#3b82f6';
        const landmarks = resizedDetection.landmarks.positions;
        landmarks.forEach(point => {
            ctx.beginPath();
            ctx.arc(point.x, point.y, 2, 0, 2 * Math.PI);
            ctx.fill();
        });
        
        ctx.restore();
        
        if (!statusLocked) {
            if (capturedDescriptors.length === 0) {
                faceStatus.textContent = 'Face detected! Ready to capture 5 images.';
            } else {
                faceStatus.textContent = `Captured ${capturedDescriptors.length}/${TOTAL_CAPTURES} images. Keep looking at camera...`;
            }
            faceStatus.className = 'face-status success';
        }

        captureFaceBtn.disabled = false;
        currentFaceDescriptor = detection.descriptor;
    } else {
        if (!statusLocked) {
            faceStatus.textContent = 'Looking for face... Please face the camera.';
            faceStatus.className = 'face-status detecting';
        }

        if (capturedDescriptors.length === 0) {
            captureFaceBtn.disabled = true;
        }
        currentFaceDescriptor = null;
    }
}

// ========================================
// START FACE DETECTION
// ========================================
async function startFaceDetection() {
    faceStatus.textContent = 'Detecting face...';
    faceStatus.className = 'face-status detecting';
    
    faceDetectionInterval = setInterval(async () => {
        await detectFace();
    }, 100);
}

// ========================================
// SHOW FACE PREVIEW
// ========================================
function showFacePreview() {
    let previewCanvas = document.getElementById('facePreviewCanvas');
    if (!previewCanvas) {
        previewCanvas = document.createElement('canvas');
        previewCanvas.id = 'facePreviewCanvas';
        previewCanvas.style.cssText = 'width: 100%; height: auto; border-radius: 8px; max-height: 250px; object-fit: cover; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);';
        facePreview.insertBefore(previewCanvas, faceDesc);
    }
    
    const ctx = previewCanvas.getContext('2d');
    previewCanvas.width = video.videoWidth;
    previewCanvas.height = video.videoHeight;
    
    ctx.save();
    ctx.scale(-1, 1);
    ctx.drawImage(video, -previewCanvas.width, 0, previewCanvas.width, previewCanvas.height);
    ctx.restore();
    
    faceIcon.style.display = 'none';
    previewCanvas.style.display = 'block';
    
    faceDesc.textContent = `Face captured successfully (${TOTAL_CAPTURES} images)`;
    faceDesc.style.color = '#86efac';
    faceDesc.style.fontWeight = '600';
    faceDesc.style.marginTop = '10px';
    
    facePreview.style.border = '2px solid rgba(34, 197, 94, 0.5)';
    facePreview.style.background = 'rgba(34, 197, 94, 0.05)';
    facePreview.style.padding = '10px';
    
    faceStatusBox.classList.add('captured');
    statusText.textContent = `✓ Face recognition enabled (${TOTAL_CAPTURES} images)`;
    
    if (!document.getElementById('removeFaceBtn')) {
        const removeBtn = document.createElement('button');
        removeBtn.id = 'removeFaceBtn';
        removeBtn.type = 'button';
        removeBtn.innerHTML = '×';
        removeBtn.style.cssText = `
            position: absolute;
            top: 15px;
            right: 15px;
            width: 32px;
            height: 32px;
            background: rgba(239, 68, 68, 0.9);
            border: none;
            border-radius: 50%;
            color: white;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            transition: all 0.3s;
            z-index: 10;
        `;
        
        removeBtn.addEventListener('click', removeFacePreview);
        removeBtn.addEventListener('mouseenter', function() {
            this.style.background = 'rgba(239, 68, 68, 1)';
            this.style.transform = 'scale(1.1)';
        });
        removeBtn.addEventListener('mouseleave', function() {
            this.style.background = 'rgba(239, 68, 68, 0.9)';
            this.style.transform = 'scale(1)';
        });
        
        facePreview.appendChild(removeBtn);
    }
}

// ========================================
// REMOVE FACE PREVIEW
// ========================================
function removeFacePreview() {
    faceDescriptorInput.value = '';
    currentFaceDescriptor = null;
    capturedDescriptors = [];
    
    const previewCanvas = document.getElementById('facePreviewCanvas');
    if (previewCanvas) previewCanvas.remove();
    
    const removeBtn = document.getElementById('removeFaceBtn');
    if (removeBtn) removeBtn.remove();
    
    faceIcon.style.display = 'block';
    faceIcon.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" fill="currentColor" class="bi bi-person-bounding-box" viewBox="0 0 16 16"><path d="M1.5 1a.5.5 0 0 0-.5.5v3a.5.5 0 0 1-1 0v-3A1.5 1.5 0 0 1 1.5 0h3a.5.5 0 0 1 0 1zM11 .5a.5.5 0 0 1 .5-.5h3A1.5 1.5 0 0 1 16 1.5v3a.5.5 0 0 1-1 0v-3a.5.5 0 0 0-.5-.5h-3a.5.5 0 0 1-.5-.5M.5 11a.5.5 0 0 1 .5.5v3a.5.5 0 0 0 .5.5h3a.5.5 0 0 1 0 1h-3A1.5 1.5 0 0 1 0 14.5v-3a.5.5 0 0 1 .5-.5m15 0a.5.5 0 0 1 .5.5v3a1.5 1.5 0 0 1-1.5 1.5h-3a.5.5 0 0 1 0-1h3a.5.5 0 0 0 .5-.5v-3a.5.5 0 0 1 .5-.5" /><path d="M3 14s-1 0-1-1 1-4 6-4 6 3 6 4-1 1-1 1zm8-9a3 3 0 1 1-6 0 3 3 0 0 1 6 0" /></svg>';
    faceDesc.textContent = 'Add face recognition for quick and secure login';
    faceDesc.style.color = 'rgba(226, 232, 240, 0.7)';
    faceDesc.style.fontWeight = 'normal';
    faceDesc.style.marginTop = '0';
    
    facePreview.style.border = '2px dashed rgba(56, 189, 248, 0.2)';
    facePreview.style.background = 'rgba(15, 23, 42, 0.4)';
    facePreview.style.padding = '20px';
    
    faceStatusBox.classList.remove('captured');
    statusText.textContent = 'Face recognition disabled';
    
    enableFaceToggle.checked = false;
    
    Swal.fire({
        background: '#121212',
        icon: 'info',
        title: 'Face Removed',
        text: 'Face recognition has been disabled.',
        confirmButtonColor: '#667eea',
        timer: 1500,
        showConfirmButton: false
    });
}

// ========================================
// OPEN MODAL
// ========================================
async function openModal() {
    faceModal.classList.add('active');
    faceStatus.textContent = 'Initializing...';
    faceStatus.className = 'face-status';
    captureFaceBtn.disabled = true;
    statusLocked = false; // fresh session, nothing to hold on screen
    capturedDescriptors = []; // Reset captures
    
    captureFaceBtn.textContent = 'Start Capturing (5 Images)';
    captureFaceBtn.style.background = '';
    
    const modelsReady = await loadFaceApiModels();
    if (!modelsReady) return;
    
    const cameraReady = await startCamera();
    if (!cameraReady) return;
    
    await startFaceDetection();
}

// ========================================
// CLOSE MODAL
// ========================================
function closeModal() {
    faceModal.classList.remove('active');
    stopCamera();
    
    if (!faceDescriptorInput.value) {
        enableFaceToggle.checked = false;
        currentFaceDescriptor = null;
        capturedDescriptors = [];
    }
}

// ========================================
// CHECK IF FACE ALREADY REGISTERED
// ========================================
async function checkFaceAlreadyRegistered(descriptor) {
    try {
        const response = await fetch('crud/check_face_duplicate.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                descriptor: Array.from(descriptor)
            })
        });
        
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Error checking face duplicate:', error);
        return { isDuplicate: false };
    }
}

// ========================================
// CAPTURE MULTIPLE FACES (5 IMAGES)
// ========================================
async function captureFace() {
    if (!currentFaceDescriptor) {
        Swal.fire({
            background: '#121212',
            icon: 'error',
            title: 'No Face Detected',
            text: 'Please ensure your face is clearly visible in the camera.',
            confirmButtonColor: '#667eea'
        });
        return;
    }
    
    // Pressing capture is the user acknowledging whatever was on the status
    // line, so the detector may write to it again from here.
    statusLocked = false;

    // Disable button during capture process
    captureFaceBtn.disabled = true;

    // Flash effect helper
    const flashEffect = () => {
        canvas.style.opacity = '0.3';
        setTimeout(() => { canvas.style.opacity = '1'; }, 150);
    };
    
    try {
        // Capture 5 images with delay
        for (let i = 0; i < TOTAL_CAPTURES; i++) {
            // Wait for face detection
            while (!currentFaceDescriptor) {
                await new Promise(resolve => setTimeout(resolve, 100));
            }
            
            // Check duplicate only on first capture
            if (i === 0) {
                captureFaceBtn.textContent = 'Checking uniqueness...';
                faceStatus.textContent = 'Verifying face is unique...';
                faceStatus.className = 'face-status detecting';
                
                const duplicateCheck = await checkFaceAlreadyRegistered(currentFaceDescriptor);
                
                if (duplicateCheck.isDuplicate) {
                    captureFaceBtn.disabled = false;
                    captureFaceBtn.textContent = 'Start Capturing (5 Images)';
                    capturedDescriptors = [];
                    
                    Swal.fire({
                        background: '#121212',
                        icon: 'error',
                        title: 'Face Already Registered!',
                        html: `
                            <p style="margin-bottom: 15px;">This face is already registered in the system.</p>
                            <p style="color: #f59e0b; font-weight: 600;">Registered to: ${duplicateCheck.userName || 'Another user'}</p>
                            <p style="color: #ef4444; font-weight: 600;">Match similarity: ${duplicateCheck.similarity}%</p>
                        `,
                        confirmButtonColor: '#667eea'
                    });
                    
                    faceStatus.textContent = duplicateCheck.userName
                        ? `Face already registered to ${duplicateCheck.userName}. Try a different face.`
                        : 'Face already exists. Please try a different face.';
                    faceStatus.className = 'face-status error';
                    // Hold it on screen. Without this the next detector pass,
                    // at most 100ms away, replaces it with "Face detected!".
                    statusLocked = true;
                    return;
                }
            }
            
            // Capture current descriptor
            capturedDescriptors.push(currentFaceDescriptor);
            flashEffect();
            
            // Update UI
            const progress = i + 1;
            captureFaceBtn.textContent = `Capturing ${progress}/${TOTAL_CAPTURES}...`;
            faceStatus.textContent = `Captured ${progress}/${TOTAL_CAPTURES} images. ${progress < TOTAL_CAPTURES ? 'Keep looking at camera...' : 'Processing...'}`;
            faceStatus.className = 'face-status success';
            
            console.log(`Captured image ${progress}/${TOTAL_CAPTURES}`);
            
            // Wait before next capture (except last one)
            if (i < TOTAL_CAPTURES - 1) {
                await new Promise(resolve => setTimeout(resolve, CAPTURE_DELAY));
            }
        }
        
        // Save all 5 descriptors as JSON array
        const descriptorsArray = capturedDescriptors.map(desc => Array.from(desc));
        faceDescriptorInput.value = JSON.stringify(descriptorsArray);
        
        // Update UI
        captureFaceBtn.textContent = '✓ All 5 Images Captured!';
        captureFaceBtn.style.background = '#4caf50';
        
        faceStatus.textContent = `Successfully captured ${TOTAL_CAPTURES} face images!`;
        faceStatus.className = 'face-status success';
        
        showFacePreview();
        
        Swal.fire({
            background: '#121212',
            icon: 'success',
            title: 'Face Registration Complete!',
            html: `
                <p>Successfully captured <strong>${TOTAL_CAPTURES} images</strong> of your face.</p>
                <p style="color: #86efac; margin-top: 10px;">This improves recognition accuracy!</p>
            `,
            confirmButtonColor: '#667eea',
            timer: 2500,
            showConfirmButton: false
        });
        
        setTimeout(() => {
            closeModal();
        }, 2500);
        
    } catch (error) {
        console.error('Error during face capture:', error);
        captureFaceBtn.disabled = false;
        captureFaceBtn.textContent = 'Start Capturing (5 Images)';
        capturedDescriptors = [];
        
        Swal.fire({
            background: '#121212',
            icon: 'error',
            title: 'Capture Failed',
            text: 'An error occurred. Please try again.',
            confirmButtonColor: '#667eea'
        });
    }
}

// ========================================
// EVENT LISTENERS
// ========================================

enableFaceToggle.addEventListener('change', async function() {
    if (this.checked) {
        await openModal();
    } else {
        removeFacePreview();
    }
});

captureFaceBtn.addEventListener('click', captureFace);
closeModalBtn.addEventListener('click', closeModal);

faceModal.addEventListener('click', function(e) {
    if (e.target === faceModal) {
        closeModal();
    }
});

document.querySelector('.face-modal-content').addEventListener('click', function(e) {
    e.stopPropagation();
});

// ========================================
// FORM SUBMISSION VALIDATION
// ========================================
const registerForm = document.getElementById('registerForm');
registerForm.addEventListener('submit', function(e) {
    const faceEnabled = enableFaceToggle.checked;
    const faceDescriptor = faceDescriptorInput.value;
    
    if (faceEnabled && !faceDescriptor) {
        e.preventDefault();
        
        Swal.fire({
            background: '#121212',
            icon: 'warning',
            title: 'Face Not Captured',
            text: 'Please capture your face or disable face recognition to continue.',
            confirmButtonColor: '#667eea'
        });
        
        return false;
    }
});