<!-- Collapsible Instructions with Icons -->
<div class="instructions-container">
    <!-- `aria-expanded` and `aria-controls` — tell a screen reader
         whether the panel this opens is currently open.
         instruction.js keeps them updated. -->
    <button type="button" id="toggleInstructions" class="toggle-btn"
        aria-expanded="false" aria-controls="instructionsContent">
        <i class="bi bi-info-circle-fill"></i>
        <span class="toggle-label">How this works</span>
    </button>

    <div id="instructionsContent" class="instructions-content">
        <ol>
            <li><i class="bi bi-person-fill"></i>Enter your <strong>Student Number</strong> (e.g., 019-464). We'll look up your record automatically.</li>
            <li><i class="bi bi-check2-square"></i>Read and accept the <strong>Terms and Conditions</strong>.</li>
            <li><i class="bi bi-qr-code-scan"></i>Click <strong>Generate</strong> to create your QR code.</li>
            <li><i class="bi bi-download"></i>Click <strong>Download QR with Details</strong> to save it to your device.</li>
        </ol>
    </div>
</div>
