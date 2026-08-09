
const toggleBtn = document.getElementById('toggleInstructions');
const instructions = document.getElementById('instructionsContent');

toggleBtn.addEventListener('click', () => {
    instructions.classList.toggle('show');
    const isShowing = instructions.classList.contains('show');

    toggleBtn.innerHTML = isShowing ?
        '<i class="bi bi-info-circle-fill" style="margin-right:6px;"></i> Hide Instructions' :
        '<i class="bi bi-info-circle-fill" style="margin-right:6px;"></i> Show Instructions';

    if (isShowing) {
        const instructionText = "Instructions: Step 1, Enter your Student Number, for example, 019-464. Step 2, Click Generate QR Code to create your QR code. Step 3, After generating, click Download QR with Details to save your QR code.";
        TTSManager.speak(instructionText);
    } else {
        TTSManager.cancel();
    }
});