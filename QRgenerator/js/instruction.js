// Opening and closing the instructions.
//
// `toggleBtn.innerHTML` used to be replaced on every press — which
// destroyed and rebuilt the icon, losing any attributes on it. Only
// the label is touched now, and aria-expanded follows the real state.

const toggleBtn = document.getElementById('toggleInstructions');
const instructions = document.getElementById('instructionsContent');
const toggleLabel = toggleBtn?.querySelector('.toggle-label');

toggleBtn?.addEventListener('click', () => {
    instructions.classList.toggle('show');
    const isShowing = instructions.classList.contains('show');

    toggleBtn.setAttribute('aria-expanded', String(isShowing));
    if (toggleLabel) {
        toggleLabel.textContent = isShowing ? 'Hide steps' : 'How this works';
    }

    if (isShowing) {
        const instructionText = "Instructions: Step 1, Enter your Student Number, for example, 019-464. Step 2, Read and accept the Terms and Conditions. Step 3, Click Generate to create your QR code. Step 4, Click Download QR with Details to save your QR code.";
        TTSManager.speak(instructionText);
    } else {
        TTSManager.cancel();
    }
});
