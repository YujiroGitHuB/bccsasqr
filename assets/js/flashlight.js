// Flashlight functionality
let currentStream = null;
let isFlashlightOn = false;

// Check if device supports flashlight
async function checkFlashlightSupport() {
    try {
        const devices = await navigator.mediaDevices.enumerateDevices();
        const videoDevices = devices.filter(device => device.kind === 'videoinput');

        // Check if any camera has torch capability
        for (let device of videoDevices) {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    deviceId: device.deviceId
                }
            });

            const track = stream.getVideoTracks()[0];
            const capabilities = track.getCapabilities();

            stream.getTracks().forEach(track => track.stop());

            if (capabilities.torch) {
                return true;
            }
        }
        return false;
    } catch (error) {
        console.log('Flashlight check error:', error);
        return false;
    }
}

// Toggle flashlight
async function toggleFlashlight() {
    const flashlightBtn = document.getElementById('flashlightBtn');
    const flashlightIcon = document.getElementById('flashlightIcon');
    const flashlightText = document.getElementById('flashlightText');

    try {
        if (!currentStream) {
            console.error('No active video stream');
            return;
        }

        const track = currentStream.getVideoTracks()[0];
        const capabilities = track.getCapabilities();

        if (!capabilities.torch) {
            alert('Your device does not support flashlight');
            return;
        }

        isFlashlightOn = !isFlashlightOn;

        await track.applyConstraints({
            advanced: [{
                torch: isFlashlightOn
            }]
        });

        // Update button appearance
        if (isFlashlightOn) {
            flashlightBtn.classList.add('active');
            flashlightIcon.classList.remove('bi-lightbulb');
            flashlightIcon.classList.add('bi-lightbulb-fill');
            flashlightText.textContent = 'Turn Off Flash';
        } else {
            flashlightBtn.classList.remove('active');
            flashlightIcon.classList.remove('bi-lightbulb-fill');
            flashlightIcon.classList.add('bi-lightbulb');
            flashlightText.textContent = 'Turn On Flash';
        }
    } catch (error) {
        console.error('Error toggling flashlight:', error);
        alert('Failed to toggle flashlight');
    }
}

// Initialize flashlight button when camera starts
async function initializeFlashlight(stream) {
    currentStream = stream;
    const flashlightBtn = document.getElementById('flashlightBtn');

    // Check if device supports flashlight
    const track = stream.getVideoTracks()[0];
    const capabilities = track.getCapabilities();

    if (capabilities.torch) {
        flashlightBtn.style.display = 'flex';
        flashlightBtn.onclick = toggleFlashlight;
    } else {
        flashlightBtn.style.display = 'none';
    }
}

// Turn off flashlight when modal closes
function disableFlashlight() {
    if (currentStream && isFlashlightOn) {
        const track = currentStream.getVideoTracks()[0];
        track.applyConstraints({
            advanced: [{
                torch: false
            }]
        }).catch(err => console.error('Error disabling flashlight:', err));

        isFlashlightOn = false;
        const flashlightBtn = document.getElementById('flashlightBtn');
        const flashlightIcon = document.getElementById('flashlightIcon');
        const flashlightText = document.getElementById('flashlightText');

        flashlightBtn.classList.remove('active');
        flashlightIcon.classList.remove('bi-lightbulb-fill');
        flashlightIcon.classList.add('bi-lightbulb');
        flashlightText.textContent = 'Turn On Flash';
    }
    currentStream = null;
}