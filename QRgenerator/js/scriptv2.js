function sanitizeInput(value) {
    return value.replace(/\s+/g, ' ').trim();
}

function generateQR() {
    const id = sanitizeInput(document.getElementById('studentNo').value);
    const name = sanitizeInput(document.getElementById('studentName').value);
    const course = sanitizeInput(document.getElementById('course').value.toUpperCase());
    const section = sanitizeInput(document.getElementById('section').value.toUpperCase());

    const swalTheme = {
        confirmButtonColor: '#38bdf8',
        background: '#0f172a',
        color: '#e2e8f0'
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

    // student number lang ang naka-encode sa QR
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

    qrWrapper.style.display = 'inline-block';
    downloadBtn.style.display = 'inline-block';
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
        background: '#0f172a',
        color: '#e2e8f0'
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

    const details = `Student Number: ${id}\nName: ${name}\nCourse: ${course}\nSection: ${section}`;

    const qrSize       = qrCanvas.width;
    const logoHeight   = 70;
    const textHeight   = 35;
    const detailsHeight = 120;
    const padding      = 30;

    const combinedCanvas = document.createElement('canvas');
    const ctx = combinedCanvas.getContext('2d');

    combinedCanvas.width  = qrSize + padding;
    combinedCanvas.height = logoHeight + textHeight + qrSize + detailsHeight;

    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, combinedCanvas.width, combinedCanvas.height);

    const logo = new Image();
    logo.src = '../assets/images/bcc-logo.png';

    logo.onload = function () {
        const logoWidth = logo.width / (logo.height / logoHeight);
        const logoX = (combinedCanvas.width - logoWidth) / 2;
        ctx.drawImage(logo, logoX, 10, logoWidth, logoHeight);

        ctx.fillStyle = '#9cacbdff';
        ctx.font = 'bold 18px Segoe UI';
        ctx.textAlign = 'center';
        ctx.fillText('BCC Student QR', combinedCanvas.width / 2, logoHeight + 30);

        const qrX = (combinedCanvas.width - qrSize) / 2;
        const qrY = logoHeight + textHeight;
        ctx.drawImage(qrCanvas, qrX, qrY, qrSize, qrSize);

        ctx.fillStyle = '#9cacbdff';
        ctx.font = '14px Segoe UI';
        ctx.textAlign = 'left';

        const startY = qrY + qrSize + 25;
        details.split('\n').forEach((line, i) => {
            ctx.fillText(line, qrX + 1, startY + i * 20);
        });

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
                background: '#0f172a',
                color: '#e2e8f0'
            });

            setTimeout(() => {
                iconSpan.innerHTML = downloadIcon;
                iconSpan.className = 'btn-icon';
                textSpan.textContent = originalText;
                btn.disabled = false;
            }, 2000);
        }, 800);
    };

    logo.onerror = function () {
        console.warn('Logo not found — downloading without logo.');

        setTimeout(() => {
            const link = document.createElement('a');
            link.download = `${id}_qr.png`;
            link.href = qrCanvas.toDataURL('image/png');
            link.click();

            iconSpan.innerHTML = successIcon;
            iconSpan.className = 'btn-icon success-icon';
            textSpan.textContent = 'Done!';

            setTimeout(() => {
                iconSpan.innerHTML = downloadIcon;
                iconSpan.className = 'btn-icon';
                textSpan.textContent = originalText;
                btn.disabled = false;
            }, 2000);
        }, 800);
    };
}