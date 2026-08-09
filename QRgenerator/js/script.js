function sanitizeInput(value) {
    return value.replace(/\s+/g, ' ').trim();
}

function generateQR() {
    const id = sanitizeInput(document.getElementById('studentNo').value);
    const name = sanitizeInput(document.getElementById('studentName').value);
    const course = sanitizeInput(document.getElementById('course').value.toUpperCase());
    const section = sanitizeInput(document.getElementById('section').value.toUpperCase());

    // Validation
    const idPattern = /^\d{3}-\d{1,5}$/;
    const namePattern = /^[A-Za-z\s.,]+$/;
    const coursePattern = /^[A-Z]{2,6}$/;
    const sectionPattern = /^\d[A-Z]$/;

    // Common SweetAlert settings
    const swalTheme = {
        confirmButtonColor: '#38bdf8',
        background: '#0f172a',
        color: '#e2e8f0'
    };

    // Empty fields
    if (!id || !name || !course || !section) {
        Swal.fire({
            icon: 'warning',
            title: 'Incomplete Fields',
            html: `
                <div style="text-align: left; line-height: 1.6;">
                    Please fill in <b>all required fields</b> before generating the QR code.<br><br>
                    <i>If you already filled everything and still see this, contact the developer for a quick debug session!</i>
                </div>
            `,
            ...swalTheme
        });
        return;
    }
    // Invalid Student Number
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
    // Invalid Section
    if (!sectionPattern.test(section)) {
        Swal.fire({
            icon: 'error',
            title: 'Invalid Section Format',
            html: `
                <div style="text-align: left; line-height: 1.6;">
                    <b>Use format like:</b> 3A, 4B, 2C, etc.<br><br>
                    <b>Invalid examples:</b><br>
                    • A3<br>
                    • 3-A<br>
                    • Sec3B<br><br>
                    <b>Valid examples:</b><br>
                    • 3A<br>
                    • 4B<br><br>
                    <i>If your section naming is special, maybe the developer can make an exception 😉</i>
                </div>
            `,
            ...swalTheme
        });
        return;
    }

    // Invalid Name
    if (!namePattern.test(name)) {
        Swal.fire({
            icon: 'error',
            title: 'Invalid Name Format',
            html: `
            <div style="text-align: left; line-height: 1.6;">
                <b>Only letters, commas, spaces, and periods</b> are allowed in the name field.<br><br>
                <b>Invalid examples:</b><br>
                • Dela Peña, Juan<br>
                • L0pez, M@ria<br>
                • Mark#Anthony<br><br>
                <b>Valid examples:</b><br>
                • Dela Cruz, Juan M.<br>
                • Cayading, Charles Nixon C.<br>
                • Santos, Anna F.<br><br>
                <i>If your name really has those characters... talk to the developer for a patch!</i>
            </div>
        `,
            ...swalTheme
        });
        return;
    }

    // Invalid Course
    if (!coursePattern.test(course)) {
        Swal.fire({
            icon: 'error',
            title: 'Invalid Course Code',
            html: `
                <div style="text-align: left; line-height: 1.6;">
                    <b>Course must contain only uppercase letters (2–6 characters)</b>.<br><br>
                    <b>Invalid examples:</b><br>
                    • bsit<br>
                    • BS-IT<br>
                    • BSIT123<br><br>
                    <b>Valid examples:</b><br>
                    • BSIT<br>
                    • BSHRM<br><br>
                    <i>If your course code is unique, message the developer for support!</i>
                </div>
            `,
            ...swalTheme
        });
        return;
    }

    const qrData = JSON.stringify({
        id: id,
        name: name,
        course: course,
        section: section
    });

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

    // SweetAlert success toast
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
    const canvas = document.querySelector('#qrcode canvas');
    if (!canvas) return;

    const id = sanitizeInput(document.getElementById('studentNo').value) || 'student';
    const name = sanitizeInput(document.getElementById('studentName').value);
    const course = sanitizeInput(document.getElementById('course').value);
    const section = sanitizeInput(document.getElementById('section').value);

    const details = `Student Number: ${id}\nName: ${name}\nCourse: ${course}\nSection: ${section}`;

    const combinedCanvas = document.createElement('canvas');
    const ctx = combinedCanvas.getContext('2d');
    const size = 300;
    combinedCanvas.width = size + 40;
    combinedCanvas.height = size + 120;

    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, combinedCanvas.width, combinedCanvas.height);

    ctx.drawImage(canvas, 20, 20, size, size);

    ctx.fillStyle = '#e2e8f0';
    ctx.font = '14px Segoe UI';
    ctx.textAlign = 'left';
    const lines = details.split('\n');
    lines.forEach((line, i) => {
        ctx.fillText(line, 20, size + 50 + i * 20);
    });

    const link = document.createElement('a');
    link.download = `${id}_qr.png`;
    link.href = combinedCanvas.toDataURL('image/png');
    link.click();

    //SweetAlert toast for download
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
}
