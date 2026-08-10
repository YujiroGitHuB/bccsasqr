<div class="right-panel">
    <h2 class="panel-title"><i class="bi bi-qr-code"></i> Your QR Code</h2>

    <!-- Ang naghihintay na estado. Dating wala talagang laman ang
         kanang kalahati hanggang sa mag-generate ka — parang
         kalahating na-load ang pahina pagdating mo. Itinatago ito
         ng scriptv2.js kapag may QR na. -->
    <div class="qr-placeholder" id="qrPlaceholder">
        <i class="bi bi-qr-code"></i>
        <span class="qr-placeholder-title">Nothing to show yet</span>
        <p>Enter your student number and accept the terms — your QR code will appear here.</p>
    </div>

    <div id="qrWrapper">
        <img
            id="qrLogo"
            src="../assets/images/bcc logo.png"
            alt="">
        <p class="qr-card-title">BCC Student QR</p>
        <div id="qrcode"></div>
        <pre id="qrText"></pre>
    </div>

    <button class="download-btn" id="downloadBtn" onclick="downloadQR()">
        <span class="btn-icon"><svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                <polyline points="7 10 12 15 17 10" />
                <line x1="12" y1="15" x2="12" y2="3" />
            </svg></span>
        <span class="btn-text">Download QR with Details</span>
    </button>
</div>
