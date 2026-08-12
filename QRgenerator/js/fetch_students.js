// ============================================================
// Student record lookup
//
// The status message used to be built here in JS and painted with
// inline styles — in white-page pastels (#fee2e2, #dcfce7, #fef9c3)
// on top of a dark form. The box now lives in the HTML
// (#studentStatus in glitch_input.php) and only its class is swapped
// here; the colors are in style.css, matching the admin badges.
//
// The same goes for the field's border: it used to be set directly
// as `input.style.border` — which CSS can never win back.
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

// The shortest time "Checking…" stays visible before it is replaced.
// There used to be a hardcoded 2,000ms `setTimeout` before the fetch
// even started — on top of the 500ms debounce, nearly two and a half
// seconds of waiting for nothing. The real call leaves immediately
// now; this only keeps the spinner from flashing on a fast
// connection.
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

    // Keep the spinner visible for at least minSpinnerMs so it does
    // not merely flash.
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

// `title` exposes the full value when the field is tight — long
// names get truncated on a phone.
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

    // The space is a non-breaking space — .btn-letter is inline-block,
    // so an ordinary space collapses and the two words run together
    // ("VerifyFirst").
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

    // The letters are aria-hidden (see button_generate.php), so the
    // button itself has to carry the name — otherwise a screen reader
    // spells it out one letter at a time.
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
