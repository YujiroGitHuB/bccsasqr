// ============================================================
//  PROFILE SETTINGS
//  One form is submitted: name, email, password, and the avatar
//  file — so there is a single "Save Changes" to press, and the
//  state cannot diverge when something fails.
// ============================================================

(function () {
    const form = document.getElementById("profileForm");
    if (!form) return;

    const avatarBlock  = document.getElementById("avatarBlock");
    const avatarInput  = document.getElementById("avatarInput");
    const avatarImg    = document.getElementById("avatarPreview");
    const removeFlag   = document.getElementById("removeAvatarFlag");
    const removeBtn    = document.getElementById("avatarRemoveBtn");
    const pickBtn      = document.getElementById("avatarPickBtn");
    const uploadBtn    = document.getElementById("avatarUploadBtn");
    const saveBtn      = document.getElementById("profileSaveBtn");
    const passwordEl   = document.getElementById("passwordField");
    const confirmEl    = document.getElementById("confirmField");
    const errorEl      = document.getElementById("passwordError");
    const toggleEye    = document.getElementById("togglePassword");
    const nameEl       = document.getElementById("nameField");

    const MAX_BYTES  = 2 * 1024 * 1024; // katumbas ng hangganan sa server
    const ALLOWED    = ["image/jpeg", "image/png", "image/webp"];
    const MIN_PW_LEN = 8;

    // The starting appearance — this is what Reset restores.
    const initialSrc = avatarImg ? (avatarImg.getAttribute("src") || "") : "";

    let objectUrl = null; // preview URL that must be revoked to avoid a leak

    const toast = (icon, title) =>
        Swal.fire({
            toast: true,
            position: "top-end",
            icon: icon,
            title: title,
            showConfirmButton: false,
            timer: 2600,
            timerProgressBar: true,
            background: "#1f1f1f",
            color: "#fff"
        });

    const showError = (msg) => {
        if (!errorEl) return;
        errorEl.textContent = msg;
        errorEl.classList.toggle("show", !!msg);
        if (confirmEl) confirmEl.classList.toggle("is-invalid", !!msg);
    };

    // The same contract for the "Confirm It's You" field. .field-error is
    // display:none until it carries .show, so setting textContent on its own
    // leaves the message in the DOM and invisible on screen.
    const currentPwEl  = document.getElementById("currentPasswordField");
    const currentPwErr = document.getElementById("currentPasswordError");
    const showCurrentError = (msg) => {
        if (!currentPwErr) return;
        currentPwErr.textContent = msg;
        currentPwErr.classList.toggle("show", !!msg);
        if (currentPwEl) currentPwEl.classList.toggle("is-invalid", !!msg);
    };
    if (currentPwEl) {
        currentPwEl.addEventListener("input", () => showCurrentError(""));
    }

    const setPreview = (src) => {
        if (!avatarImg || !avatarBlock) return;
        if (src) {
            avatarImg.src = src;
        } else {
            avatarImg.removeAttribute("src"); // not `src=""` — that would fetch the page URL
        }
        avatarBlock.classList.toggle("has-photo", !!src);
        if (removeBtn) removeBtn.disabled = !src;
    };

    const releaseObjectUrl = () => {
        if (objectUrl) {
            URL.revokeObjectURL(objectUrl);
            objectUrl = null;
        }
    };

    // ── Pagpili ng larawan ──────────────────────────────────
    const openPicker = () => avatarInput && avatarInput.click();
    if (pickBtn) pickBtn.addEventListener("click", openPicker);
    if (uploadBtn) uploadBtn.addEventListener("click", openPicker);

    if (avatarInput) {
        avatarInput.addEventListener("change", function () {
            const file = this.files && this.files[0];
            if (!file) return;

            // The server checks this too — done here only to avoid
            // uploading 5MB before finding out it is rejected.
            if (!ALLOWED.includes(file.type)) {
                toast("warning", "Only JPG, PNG, or WEBP images are allowed.");
                this.value = "";
                return;
            }

            if (file.size > MAX_BYTES) {
                toast("warning", "Image is too large (max 2 MB).");
                this.value = "";
                return;
            }

            releaseObjectUrl();
            objectUrl = URL.createObjectURL(file);
            setPreview(objectUrl);
            if (removeFlag) removeFlag.value = "0"; // cancels an earlier "remove"
        });
    }

    // ── Pagtanggal ng larawan ───────────────────────────────
    if (removeBtn) {
        removeBtn.addEventListener("click", function () {
            releaseObjectUrl();
            if (avatarInput) avatarInput.value = "";
            if (removeFlag) removeFlag.value = "1";
            setPreview("");
            toast("info", "Photo will be removed when you save.");
        });
    }

    // ── Show / hide password ────────────────────────────────
    if (toggleEye && passwordEl) {
        toggleEye.addEventListener("click", function () {
            const show = passwordEl.type === "password";
            passwordEl.type = show ? "text" : "password";
            this.innerHTML = show ? '<i class="bi bi-eye-slash"></i>' : '<i class="bi bi-eye"></i>';
            this.setAttribute("aria-label", show ? "Hide password" : "Show password");
        });
    }

    if (confirmEl) confirmEl.addEventListener("input", () => showError(""));
    if (passwordEl) passwordEl.addEventListener("input", () => showError(""));

    // ── Reset: restore the starting avatar, not just the text ──
    form.addEventListener("reset", function () {
        releaseObjectUrl();
        if (removeFlag) removeFlag.value = "0";
        if (avatarInput) avatarInput.value = "";
        setPreview(initialSrc);
        showError("");
        showCurrentError("");
    });

    // ── Submit ──────────────────────────────────────────────
    form.addEventListener("submit", function (e) {
        e.preventDefault();

        const pw      = passwordEl ? passwordEl.value : "";
        const confirm = confirmEl ? confirmEl.value : "";

        if (pw !== "") {
            if (pw.length < MIN_PW_LEN) {
                showError("Password must be at least " + MIN_PW_LEN + " characters.");
                passwordEl.focus();
                return;
            }
            if (pw !== confirm) {
                showError("Passwords do not match.");
                confirmEl.focus();
                return;
            }
        }
        showError("");

        // crud/updateProfile.php re-authenticates a password or face change.
        // Catching it here saves a round trip and, more to the point, saves
        // the user from losing a five-shot face capture to a rejected save.
        const faceEl   = document.getElementById("faceDescriptorField");
        const removeEl = document.getElementById("removeFaceField");
        const faceTouched =
            (faceEl && faceEl.value !== "") ||
            (removeEl && removeEl.value === "1");

        showCurrentError("");

        if ((pw !== "" || faceTouched) && currentPwEl && currentPwEl.value === "") {
            showCurrentError("Enter your current password to confirm this change.");
            currentPwEl.focus();
            return;
        }

        const formData = new FormData(this);
        const original = saveBtn ? saveBtn.innerHTML : "";

        if (saveBtn) {
            saveBtn.disabled = true;
            saveBtn.innerHTML = '<i class="bi bi-arrow-repeat"></i> Saving...';
        }

        fetch("../crud/updateProfile.php", {
            method: "POST",
            body: formData
        })
            .then((res) => res.json())
            .then((data) => {
                toast(data.status, data.message);

                if (data.status !== "success") {
                    // The server names the field it rejected, so the message
                    // lands next to the input rather than only in a toast the
                    // user has to remember.
                    if (data.field === "current_password") {
                        showCurrentError(data.message);
                        if (currentPwEl) { currentPwEl.value = ""; currentPwEl.focus(); }
                    }
                    return;
                }

                // Clear the password fields — there is no reason for
                // plaintext to sit in the DOM after saving.
                if (passwordEl) passwordEl.value = "";
                if (confirmEl) confirmEl.value = "";
                if (avatarInput) avatarInput.value = "";
                if (removeFlag) removeFlag.value = "0";

                // The confirmation is spent — it re-authorised this one save
                // and must not sit in the DOM ready to authorise the next.
                if (currentPwEl) currentPwEl.value = "";
                showCurrentError("");

                // Update the topbar alongside so no refresh is needed.
                const topbarImg  = document.querySelector(".topbar .profile img");
                const topbarName = document.querySelector(".topbar .profile-name");
                const nameLabel  = document.getElementById("profileNameLabel");

                if (data.avatar_url) {
                    const url = "../" + data.avatar_url + "?v=" + Date.now();
                    releaseObjectUrl();
                    setPreview(url);
                    if (topbarImg) topbarImg.src = url;
                } else if (data.avatar_removed) {
                    releaseObjectUrl();
                    setPreview("");
                }

                if (nameEl) {
                    if (topbarName) topbarName.textContent = nameEl.value;
                    if (nameLabel) nameLabel.textContent = nameEl.value;
                }

                // assets/js/profileFace.js keeps its own idea of what the
                // server holds so it can tell "saved" from "staged". It has
                // no other way to learn a save went through.
                document.dispatchEvent(new CustomEvent("profile:saved", { detail: data }));
            })
            .catch(() => {
                Swal.fire({
                    icon: "error",
                    title: "Error",
                    text: "Something went wrong.",
                    background: "#1f1f1f",
                    color: "#fff"
                });
            })
            .finally(() => {
                if (saveBtn) {
                    saveBtn.disabled = false;
                    saveBtn.innerHTML = original;
                }
            });
    });
})();
