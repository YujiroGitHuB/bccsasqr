function sanitizeInput(value) {
    return value.replace(/\s+/g, ' ').trim();
}

function generateQR() {
    const id = sanitizeInput(document.getElementById('studentNo').value);
    const name = sanitizeInput(document.getElementById('studentName').value);
    const course = sanitizeInput(document.getElementById('course').value.toUpperCase());
    const section = sanitizeInput(document.getElementById('section').value.toUpperCase());

    // Matches the page's surface and accent (see style.css).
    const swalTheme = {
        confirmButtonColor: '#0ea5e9',
        background: '#16161a',
        color: '#e7e9ee'
    };

    // Empty student number
    if (!id) {
        Swal.fire({
            icon: 'warning',
            title: 'Student Number Required',
            text: 'Please enter your Student Number before generating the QR code.',
            ...swalTheme
        });
        return;
    }

    // Invalid Student Number format
    const idPattern = /^\d{3}-\d{1,5}$/;
    if (!idPattern.test(id)) {
        Swal.fire({
            icon: 'error',
            title: 'Invalid Student Number',
            html: `
                <div style="text-align: left; line-height: 1.6;">
                    <b>Use format:</b> YEAR-NUMBER<br>
                    (e.g., 019-464 or 025-1023)<br><br>
                    <b>Invalid examples:</b><br>
                    • 2025/001<br>
                    • 25-001<br>
                    • ABC-123<br><br>
                    <i>If your school uses a different format, let your friendly developer know!</i>
                </div>
            `,
            ...swalTheme
        });
        return;
    }

    // Student details must be loaded from DB first
    if (!name || !course || !section) {
        Swal.fire({
            icon: 'warning',
            title: 'Student Not Verified',
            text: 'Please wait for your student record to load before generating.',
            ...swalTheme
        });
        return;
    }

    // only the student number is encoded in the QR
    const qrData = id;

    document.getElementById('qrText').innerText =
        `Student Number: ${id}\nName: ${name}\nCourse: ${course}\nSection: ${section}`;

    const qrContainer = document.getElementById('qrcode');
    qrContainer.innerHTML = "";

    new QRCode(qrContainer, {
        text: qrData,
        width: 250,
        height: 250,
        colorDark: "#38bdf8",
        colorLight: "#0f172a",
        correctLevel: QRCode.CorrectLevel.M
    });

    qrContainer.style.opacity = "1";
    qrContainer.style.transform = "scale(1)";

    const qrWrapper = document.getElementById('qrWrapper');
    const downloadBtn = document.getElementById('downloadBtn');
    const placeholder = document.getElementById('qrPlaceholder');

    // There is a QR now — the waiting state has nothing left to wait
    // for.
    if (placeholder) placeholder.style.display = 'none';

    qrWrapper.style.display = 'block';
    downloadBtn.style.display = 'flex';
    setTimeout(() => {
        qrWrapper.style.opacity = '1';
        qrWrapper.style.transform = 'scale(1)';
    }, 50);

    Swal.fire({
        icon: 'success',
        title: 'QR Code Generated!',
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: 2000,
        background: '#16161a',
        color: '#e7e9ee'
    });
}

function downloadQR() {
    const btn = document.getElementById('downloadBtn');
    const textSpan = btn.querySelector('.btn-text');
    const iconSpan = btn.querySelector('.btn-icon');
    const originalText = textSpan.textContent;

    const downloadIcon = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
            <polyline points="7 10 12 15 17 10"/>
            <line x1="12" y1="15" x2="12" y2="3"/>
        </svg>
    `;

    const loadingIcon = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10" opacity="0.25"/>
            <path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round"/>
        </svg>
    `;

    const successIcon = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
    `;

    btn.disabled = true;
    iconSpan.innerHTML = loadingIcon;
    iconSpan.className = 'btn-icon loading-icon';
    textSpan.textContent = 'Downloading...';

    const qrCanvas = document.querySelector('#qrcode canvas');
    if (!qrCanvas) {
        iconSpan.innerHTML = downloadIcon;
        iconSpan.className = 'btn-icon';
        textSpan.textContent = originalText;
        btn.disabled = false;
        return;
    }

    const id     = sanitizeInput(document.getElementById('studentNo').value) || 'student';
    const name   = sanitizeInput(document.getElementById('studentName').value);
    const course = sanitizeInput(document.getElementById('course').value);
    const section = sanitizeInput(document.getElementById('section').value);

    const details = [
        ['Student No.', id],
        ['Name', name],
        ['Course', course],
        ['Section', section]
    ];

    /* ── The printed card ─────────────────────────────────────────
       This is the only part a student carries out of the system, so
       it should look like it came from here: an accent rule on top,
       clean type, and the details aligned as label/value rather than
       one lump of "Label: Value" text.

       The background color MUST stay identical to the QR's
       `colorLight` above — if they differ, a visible square seam
       appears around the code.

       The QR's own colors are left alone. jsQR in
       Qrscanner/js/scriptV3.js is called with no options, so its
       default is "attemptBoth" and it reads an inverted QR — but not
       every other scanner does. */
    const QR_BG = '#0f172a';   // = colorLight above
    const INK = '#e2e8f0';
    const INK_DIM = '#8b9bb0';
    const FONT = '"Segoe UI", system-ui, -apple-system, Roboto, sans-serif';

    const qrSize = qrCanvas.width;
    const margin = 28;
    const logoHeight = 58;
    const rowHeight = 22;
    const width = qrSize + margin * 2;

    const combinedCanvas = document.createElement('canvas');
    const ctx = combinedCanvas.getContext('2d');
    combinedCanvas.width = width;

    // Draws the whole card. Both logo paths call it (found / not
    // found) — previously the error path downloaded a bare QR with no
    // details at all, leaving no name on the image.
    //
    // The height depends on whether there is a logo: without one, no
    // space is reserved for it rather than leaving a gap.
    function paintCard(logoImg) {
        const logoBlock = logoImg ? logoHeight + 24 : 0;
        const titleY = margin + logoBlock + 14;
        const qrY = titleY + 18;
        const dividerY = qrY + qrSize + 22;
        const detailsY = dividerY + 26;
        const height = detailsY + details.length * rowHeight + margin - 6;

        combinedCanvas.height = height;

        ctx.fillStyle = QR_BG;
        ctx.fillRect(0, 0, width, height);

        // Guhit ng tuldik sa itaas — kapareho ng hero ng pahina.
        const bar = ctx.createLinearGradient(0, 0, width, 0);
        bar.addColorStop(0, '#0ea5e9');
        bar.addColorStop(1, '#06b6d4');
        ctx.fillStyle = bar;
        ctx.fillRect(0, 0, width, 4);

        if (logoImg) {
            const logoWidth = logoImg.width / (logoImg.height / logoHeight);
            ctx.drawImage(logoImg, (width - logoWidth) / 2, margin, logoWidth, logoHeight);
        }

        ctx.textAlign = 'center';
        ctx.fillStyle = INK;
        ctx.font = `600 17px ${FONT}`;
        ctx.fillText('BCC Student QR', width / 2, titleY);

        ctx.drawImage(qrCanvas, margin, qrY, qrSize, qrSize);

        ctx.strokeStyle = 'rgba(255,255,255,.1)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(margin, dividerY + .5);
        ctx.lineTo(width - margin, dividerY + .5);
        ctx.stroke();

        // Label left, value right — it reads across even when the
        // names are of different lengths.
        details.forEach(([label, value], i) => {
            const y = detailsY + i * rowHeight;

            ctx.textAlign = 'left';
            ctx.fillStyle = INK_DIM;
            ctx.font = `13px ${FONT}`;
            ctx.fillText(label, margin, y);

            ctx.textAlign = 'right';
            ctx.fillStyle = INK;
            ctx.font = `600 13px ${FONT}`;
            ctx.fillText(value || '—', width - margin, y);
        });
    }

    function finish() {
        setTimeout(() => {
            const link = document.createElement('a');
            link.download = `${id}_qr.png`;
            link.href = combinedCanvas.toDataURL('image/png');
            link.click();

            iconSpan.innerHTML = successIcon;
            iconSpan.className = 'btn-icon success-icon';
            textSpan.textContent = 'Done!';

            Swal.fire({
                icon: 'success',
                title: 'QR Code Downloaded!',
                toast: true,
                position: 'top-end',
                showConfirmButton: false,
                timer: 2000,
                background: '#16161a',
                color: '#e7e9ee'
            });

            setTimeout(() => {
                iconSpan.innerHTML = downloadIcon;
                iconSpan.className = 'btn-icon';
                textSpan.textContent = originalText;
                btn.disabled = false;
            }, 2000);
        }, 600);
    }

    const logo = new Image();
    logo.src = '../assets/images/bcc-logo.png';

    logo.onload = function () {
        paintCard(logo);
        finish();
    };

    logo.onerror = function () {
        console.warn('Logo not found — downloading without logo.');
        paintCard(null);
        finish();
    };
}