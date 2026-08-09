// Modal functionality
const faceLoginTab = document.getElementById('faceLoginTab');
const faceLoginModal = document.getElementById('faceLoginModal');
const closeModalBtn = document.getElementById('closeModalBtn');
const passwordTab = document.querySelector('.login-tab[data-method="password"]');

// Open modal and AUTO-START face recognition
faceLoginTab.addEventListener('click', async (e) => {
    e.preventDefault();
    faceLoginModal.classList.add('show');

    // AUTO-START face login when modal opens
    await startFaceLogin();
});

// Close modal function
function closeModal() {
    // Stop face login and clear resources
    if (typeof stopFaceLogin === 'function') {
        stopFaceLogin();
    }

    // 🔦 Turn off flashlight when closing
    disableFlashlight();

    // Extra cleanup - clear canvas
    const canvas = document.getElementById('loginFaceCanvas');
    if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    }

    // Hide modal
    faceLoginModal.classList.remove('show');

    // Keep password tab active
    document.querySelectorAll('.login-tab').forEach(t => t.classList.remove('active'));
    passwordTab.classList.add('active');
}

// Close modal ONLY when clicking X button
closeModalBtn.addEventListener('click', closeModal);

// ❌ REMOVED: Click outside to close modal

// Close modal with ESC key (optional - you can remove this if you want)
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && faceLoginModal.classList.contains('show')) {
        closeModal();
    }
});