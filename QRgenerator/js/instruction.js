// Ang pagbukas-sara ng mga tagubilin.
//
// Dati, `toggleBtn.innerHTML` ang pinapalitan sa bawat pindot —
// tinatanggal nito ang icon at muling ginagawa, at nawawala ang
// anumang atributo. Ang label na lang ang hinihipo ngayon, at
// sinusundan ng aria-expanded ang totoong estado.

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
