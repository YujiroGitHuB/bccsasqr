// ============================================================
// Paghahanap ng talaan ng estudyante
//
// Ang mensahe ng estado ay ginagawa dati rito sa JS at ipininta ng
// inline na estilo — at pastel pang-puting-pahina ang mga kulay
// (#fee2e2, #dcfce7, #fef9c3) sa ibabaw ng madilim na porma.
// Nasa HTML na ngayon ang kahon (#studentStatus sa glitch_input.php)
// at klase na lang ang ipinapalit dito; nasa style.css ang kulay,
// katugma ng mga badge sa admin.
//
// Ganoon din ang gilid ng patlang: dating `input.style.border` na
// itinatakda nang diretso — hindi na iyon kayang bawiin ng CSS
// kahit kailan.
// ============================================================

const studentNoInput = document.getElementById("studentNo");
const nameField = document.getElementById("studentName");
const courseField = document.getElementById("course");
const sectionField = document.getElementById("section");
const generateBtn = document.getElementById("generateBtn");

const studentNoField = document.getElementById("studentNoField");
const lockedFields = document.getElementById("lockedFields");
const message = document.getElementById("studentStatus");

let typingTimer;
const doneTypingInterval = 500;

// Ang pinakamaikling panahong nakikita ang "Checking…" bago ito
// mapalitan. Dati, may hardcoded na 2,000ms na `setTimeout` bago
// pa man magsimula ang fetch — dagdag pa sa 500ms na debounce,
// halos dalawa't kalahating segundo ng paghihintay na wala namang
// ginagawa. Ang totoong tawag ay agad nang umaalis ngayon; ito ay
// para lang hindi kumisap ang spinner sa mabilis na koneksiyon.
const minSpinnerMs = 350;

studentNoInput.addEventListener("input", function () {
    clearTimeout(typingTimer);
    typingTimer = setTimeout(validateAndFetchStudent, doneTypingInterval);
});

function validateAndFetchStudent() {
    const studentNo = studentNoInput.value.trim();
    const pattern = /^\d{3}-\d{3,4}$/;

    if (studentNo === "") {
        clearMessage();
        resetFields();
        setFieldState("");
        window.speechSynthesis.cancel();
        disableGenerateButton();
        return;
    }

    // Invalid Format
    if (!pattern.test(studentNo)) {
        setFieldState("is-bad");
        const msg = "Invalid format. Use YEAR-NUMBER, e.g. 019-464.";
        setMessage(msg, "is-bad", "bi-exclamation-triangle-fill");
        TTSManager.speak("Invalid format. Try again");
        resetFields();
        disableGenerateButton();
        return;
    }

    // Show "Checking" state immediately
    setFieldState("is-checking");
    setMessage("Checking student record…", "is-checking", null, true);
    TTSManager.speak("Checking student record");
    disableGenerateButton();

    const startedAt = Date.now();

    // Panatilihing nakikita ang spinner nang hindi bababa sa
    // minSpinnerMs para hindi ito kumisap lang.
    const settle = (fn) => {
        const elapsed = Date.now() - startedAt;
        setTimeout(fn, Math.max(0, minSpinnerMs - elapsed));
    };

    fetch(`../includes/fetch_students.php?studentNo=${encodeURIComponent(studentNo)}`)
        .then(res => res.json())
        .then(data => settle(() => {
            if (data.error) {
                setFieldState("is-bad");
                const msg = "Student not found. Please check your Student Number.";
                setMessage(msg, "is-bad", "bi-x-circle-fill");
                TTSManager.speak("Student not found. Please check your Student Number and try again.");
                resetFields();
                disableGenerateButton();
            } else {
                setFieldState("is-ok");
                setLocked(nameField, data.fullname);
                setLocked(courseField, data.course);
                setLocked(sectionField, data.section);
                lockedFields?.classList.add("is-filled");
                const msg = "Verified — your record was loaded.";
                setMessage(msg, "is-ok", "bi-check-circle-fill");
                TTSManager.speak("Verified Student! Loaded Successfully!");
                enableGenerateButton(); // This will change text to "Generate"
            }
        }))
        .catch(() => settle(() => {
            setFieldState("is-warn");
            const msg = "Couldn't reach the server. Check your connection and try again.";
            setMessage(msg, "is-warn", "bi-wifi-off");
            TTSManager.speak("Database connection error");
            disableGenerateButton();
        }));
}

// Helpers
function setMessage(text, state, icon, spinner) {
    if (!message) return;

    const lead = spinner
        ? '<span class="spinner"></span>'
        : (icon ? `<i class="bi ${icon}" aria-hidden="true"></i>` : '');

    message.innerHTML = `${lead}<span>${text}</span>`;
    message.className = `qr-status is-visible ${state}`;
}

function clearMessage() {
    if (!message) return;
    message.className = "qr-status";
    message.innerHTML = "";
}

function setFieldState(state) {
    if (!studentNoField) return;
    studentNoField.className = `qr-field qr-field-primary ${state}`.trim();
}

// Ang `title` ang nagpapakita ng buong halaga kapag masikip ang
// patlang — naputol ang mahahabang pangalan sa telepono.
function setLocked(field, value) {
    field.value = value ?? "";
    field.title = value ?? "";
}

function resetFields() {
    setLocked(nameField, "");
    setLocked(courseField, "");
    setLocked(sectionField, "");
    lockedFields?.classList.remove("is-filled");
}

// Function to change button text to "Generate"
function setButtonText(text1, text2) {
    const btnText1 = document.getElementById("btnText1");
    const btnText2 = document.getElementById("btnText2");

    // Clear existing letters
    btnText1.innerHTML = "";
    btnText2.innerHTML = "";

    // Non-breaking space ang espasyo — inline-block ang .btn-letter
    // kaya nagco-collapse ang ordinaryong space at nagdidikit ang
    // dalawang salita ("VerifyFirst").
    const letter = (char) => (char === " " ? " " : char);

    // Add new letters for text1
    for (let char of text1) {
        const span = document.createElement("span");
        span.className = "btn-letter";
        span.textContent = letter(char);
        btnText1.appendChild(span);
    }

    // Add new letters for text2
    for (let char of text2) {
        const span = document.createElement("span");
        span.className = "btn-letter";
        span.textContent = letter(char);
        btnText2.appendChild(span);
    }

    // Naka-aria-hidden ang mga titik (tingnan ang button_generate.php)
    // kaya ang butones mismo ang kailangang magdala ng pangalan —
    // kung hindi, babaybayin ito ng screen reader nang tig-iisang
    // letra.
    generateBtn.setAttribute("aria-label", text1);
}

// Updated button functions
function enableGenerateButton() {
    generateBtn.disabled = false;
    generateBtn.style.cursor = "pointer";
    setButtonText("Generate", "Generating");
}

function disableGenerateButton() {
    generateBtn.disabled = true;
    generateBtn.style.cursor = "not-allowed";
    setButtonText("Verify First", "Verify First");
}
