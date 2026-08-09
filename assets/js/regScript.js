const form = document.getElementById('registerForm');
const name = document.getElementById('name');
const email = document.getElementById('email');
const password = document.getElementById('password');
const confirmPassword = document.getElementById('confirmPassword');
const enableFaceRecognition = document.getElementById('enableFaceRecognition');
const message = document.getElementById('message');
const strengthIndicator = document.querySelector('.password-strength');
const strengthText = document.querySelector('.password-strength-text');
const requirementsList = document.querySelector('.password-requirements');

// Requirement elements
const reqLength = document.getElementById('req-length');
const reqLengthStrong = document.getElementById('req-length-strong');
const reqCase = document.getElementById('req-case');
const reqNumber = document.getElementById('req-number');
const reqSpecial = document.getElementById('req-special');

// Validation functions
function validateName() {
    if (name.value.trim() !== "") {
        name.classList.add('valid');
        name.classList.remove('invalid');
        return true;
    } else {
        name.classList.remove('valid');
        if (name.value.length > 0) name.classList.add('invalid');
        return false;
    }
}

function validateEmail() {
    const emailPattern = /^[^ ]+@[^ ]+\.[a-z]{2,3}$/;
    const validEmail = emailPattern.test(email.value.trim());

    if (validEmail) {
        email.classList.add('valid');
        email.classList.remove('invalid');
        return true;
    } else {
        email.classList.remove('valid');
        if (email.value.length > 0) email.classList.add('invalid');
        return false;
    }
}

function validatePassword() {
    if (password.value.length >= 6) {
        password.classList.add('valid');
        password.classList.remove('invalid');
        return true;
    } else {
        password.classList.remove('valid');
        if (password.value.length > 0) password.classList.add('invalid');
        return false;
    }
}

function validateConfirmPassword() {
    if (confirmPassword.value !== "" && password.value === confirmPassword.value) {
        confirmPassword.classList.add('valid');
        confirmPassword.classList.remove('invalid');
        return true;
    } else {
        confirmPassword.classList.remove('valid');
        if (confirmPassword.value.length > 0) confirmPassword.classList.add('invalid');
        return false;
    }
}

function validateFaceRecognition() {
    if (enableFaceRecognition.checked) {
        return true;
    } else {
        return false;
    }
}

// Real-time validation
name.addEventListener('input', validateName);
name.addEventListener('blur', validateName);

email.addEventListener('input', validateEmail);
email.addEventListener('blur', validateEmail);

password.addEventListener('input', function () {
    validatePassword();
    validateConfirmPassword(); // Re-check confirm password when password changes

    // Password strength checker
    const value = this.value;

    if (value.length === 0) {
        strengthIndicator.classList.remove('show');
        requirementsList.classList.remove('show');
        return;
    }

    strengthIndicator.classList.add('show');
    requirementsList.classList.add('show');

    let strength = 0;

    // Check each requirement
    const hasLength = value.length >= 6;
    const hasLengthStrong = value.length >= 10;
    const hasCase = /[a-z]/.test(value) && /[A-Z]/.test(value);
    const hasNumber = /\d/.test(value);
    const hasSpecial = /[^a-zA-Z\d]/.test(value);

    // Update requirement indicators
    reqLength.classList.toggle('met', hasLength);
    reqLengthStrong.classList.toggle('met', hasLengthStrong);
    reqCase.classList.toggle('met', hasCase);
    reqNumber.classList.toggle('met', hasNumber);
    reqSpecial.classList.toggle('met', hasSpecial);

    // Calculate strength
    if (hasLength) strength++;
    if (hasLengthStrong) strength++;
    if (hasCase) strength++;
    if (hasNumber) strength++;
    if (hasSpecial) strength++;

    strengthText.className = 'password-strength-text';

    if (strength <= 2) {
        strengthText.classList.add('strength-weak');
        strengthText.textContent = 'Weak Password!';
        // TTS only if TTSManager exists
        if (typeof TTSManager !== 'undefined') {
            TTSManager.speak('Your password is too weak. Please use a stronger password.');
        }
    } else if (strength === 3) {
        strengthText.classList.add('strength-medium');
        strengthText.textContent = 'Medium Password!';
        if (typeof TTSManager !== 'undefined') {
            TTSManager.speak('Your password is okay, but adding more characters or symbols will make it stronger.');
        }
    } else if (strength === 4) {
        strengthText.classList.add('strength-strong');
        strengthText.textContent = 'Strong Password!';
        if (typeof TTSManager !== 'undefined') {
            TTSManager.speak('Good job! Your password is strong and secure.');
        }
    } else {
        strengthText.classList.add('strength-very-strong');
        strengthText.textContent = 'Very Strong Password!';
        if (typeof TTSManager !== 'undefined') {
            TTSManager.speak('Excellent! Your password is very strong and highly secure.');
        }
    }
});

password.addEventListener('blur', validatePassword);

confirmPassword.addEventListener('input', validateConfirmPassword);
confirmPassword.addEventListener('blur', validateConfirmPassword);

// Toggle password visibility
const togglePassword = document.getElementById('togglePassword');
const toggleConfirmPassword = document.getElementById('toggleConfirmPassword');

togglePassword.addEventListener('click', function () {
    const type = password.type === 'password' ? 'text' : 'password';
    password.type = type;
    this.classList.toggle('active');
});

toggleConfirmPassword.addEventListener('click', function () {
    const type = confirmPassword.type === 'password' ? 'text' : 'password';
    confirmPassword.type = type;
    this.classList.toggle('active');
});

// Form submission
form.addEventListener('submit', function (e) {
    e.preventDefault();

    message.classList.remove('show', 'error', 'success');

    if (name.value.trim() === "") {
        showMessage("Please enter your full name.", "error");
    } else if (!validateEmail()) {
        showMessage("Invalid email format!", "error");
    } else if (password.value.length < 6) {
        showMessage("Password must be at least 6 characters.", "error");
    } else if (password.value !== confirmPassword.value) {
        showMessage("Passwords do not match!", "error");
    } else if (!validateFaceRecognition()) {
        showMessage("Please enable Face Login to continue.", "error");
    } else {
        // All validation passed - submit the form to PHP backend
        form.submit();
    }
});

function showMessage(text, type) {
    message.textContent = text;
    message.className = `message show ${type}`;
    
    // TTS for error messages
    if (type === 'error' && typeof TTSManager !== 'undefined') {
        TTSManager.speak(text);
    }
    
    setTimeout(() => {
        message.classList.remove('show');
    }, 3000);
}