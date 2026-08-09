const studentNoInput = document.getElementById("studentNo");
const nameField = document.getElementById("studentName");
const courseField = document.getElementById("course");
const sectionField = document.getElementById("section");
const generateBtn = document.getElementById("generateBtn");

// Create visible message box below input
const message = document.createElement("div");
message.style.marginTop = "10px";
message.style.marginBottom = "6px";
message.style.padding = "10px 14px";
message.style.borderRadius = "10px";
message.style.fontSize = "0.9rem";
message.style.transition = "all 0.3s ease";
message.style.fontFamily = "Times New Roman', Times, serif";
message.style.display = "none";
message.style.fontWeight = "500";
message.style.lineHeight = "1.4";

// Center horizontally
message.style.textAlign = "center";
message.style.marginLeft = "auto";
message.style.marginRight = "auto";
message.style.display = "block";

document.querySelector('label[for="studentNo"]').insertAdjacentElement("afterend", message);

let typingTimer;
const doneTypingInterval = 500;

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
        studentNoInput.style.border = "1px solid #cbd5e1";
        window.speechSynthesis.cancel();
        disableGenerateButton();
        return;
    }

    // Invalid Format
    if (!pattern.test(studentNo)) {
        setTimeout(() => {
            studentNoInput.style.border = "2px solid #ef4444";
            const msg = "Invalid format. Try Again";
            setMessage(msg, "#fee2e2", "#b91c1c");
            TTSManager.speak(msg);
            resetFields();
            disableGenerateButton();
        }, 300);
        return;
    }

    // Show "Checking" state immediately
    studentNoInput.style.border = "2px solid #38bdf8";
    setMessage(`<div class="spinner"></div> Checking Student Record...`, "#e0f2fe", "#075985");
    TTSManager.speak("Checking student record");
    disableGenerateButton();

    // Add delay before making the actual fetch request
    setTimeout(() => {
        fetch(`../includes/fetch_students.php?studentNo=${encodeURIComponent(studentNo)}`)
            .then(res => res.json())
            .then(data => {
                if (data.error) {
                    studentNoInput.style.border = "2px solid #ef4444";
                    const msg = "Student not found. Please check your Student Number and try again.";
                    setMessage(msg, "#fee2e2", "#b91c1c");
                    TTSManager.speak(msg);
                    resetFields();
                    disableGenerateButton();
                } else {
                    studentNoInput.style.border = "2px solid #22c55e";
                    nameField.value = data.fullname;
                    courseField.value = data.course;
                    sectionField.value = data.section;
                    const msg = "Verified Student! Loaded Successfully!";
                    setMessage(msg, "#dcfce7", "#166534");
                    TTSManager.speak(msg);
                    enableGenerateButton(); // This will change text to "Generate"
                }
            })
            .catch(() => {
                studentNoInput.style.border = "2px solid #facc15";
                const msg = "Database connection error";
                setMessage(msg, "#fef9c3", "#854d0e");
                TTSManager.speak(msg);
                disableGenerateButton();
            });
    }, 2000);
}

// Helpers
function setMessage(text, bg, color) {
    message.innerHTML = text;
    message.style.background = bg;
    message.style.color = color;
    message.style.display = "block";
    message.style.boxShadow = "0 3px 12px rgba(0,0,0,0.05)";
}

function clearMessage() {
    message.style.display = "none";
}

function resetFields() {
    nameField.value = "";
    courseField.value = "";
    sectionField.value = "";
}

// Function to change button text to "Generate"
function setButtonText(text1, text2) {
    const btnText1 = document.getElementById("btnText1");
    const btnText2 = document.getElementById("btnText2");
    
    // Clear existing letters
    btnText1.innerHTML = "";
    btnText2.innerHTML = "";
    
    // Add new letters for text1
    for (let char of text1) {
        const span = document.createElement("span");
        span.className = "btn-letter";
        span.textContent = char;
        btnText1.appendChild(span);
    }
    
    // Add new letters for text2
    for (let char of text2) {
        const span = document.createElement("span");
        span.className = "btn-letter";
        span.textContent = char;
        btnText2.appendChild(span);
    }
}

// Updated button functions
function enableGenerateButton() {
    generateBtn.disabled = false;
    generateBtn.style.opacity = "1";
    generateBtn.style.cursor = "pointer";
    setButtonText("Generate", "Generating"); // Change to Generate/Generating
}

function disableGenerateButton() {
    generateBtn.disabled = true;
    generateBtn.style.opacity = "0.5";
    generateBtn.style.cursor = "not-allowed";
    setButtonText("Verify First", "Verify First"); // Keep as Verify First
}