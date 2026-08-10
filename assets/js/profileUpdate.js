// ============================================================
//  PROFILE SETTINGS
//  Isang form lang ang ipinapadala: pangalan, email, password, at
//  ang avatar file — kaya iisang "Save Changes" ang kailangan
//  pindutin at hindi maghihiwalay ang state kapag may nabigo.
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

    // Panimulang itsura — ibinabalik ito ng Reset.
    const initialSrc = avatarImg ? (avatarImg.getAttribute("src") || "") : "";

    let objectUrl = null; // preview URL na kailangang bawiin para hindi mag-leak

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

    const setPreview = (src) => {
        if (!avatarImg || !avatarBlock) return;
        if (src) {
            avatarImg.src = src;
        } else {
            avatarImg.removeAttribute("src"); // hindi `src=""` — page URL ang hihilahin niyan
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

            // Sinusuri rin ito sa server — dito lang para hindi pa
            // mag-upload ng 5MB bago malamang tanggi pala.
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
            if (removeFlag) removeFlag.value = "0"; // kinakansela ang naunang "remove"
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

    // ── Reset: ibalik ang panimulang avatar, hindi lang ang text ──
    form.addEventListener("reset", function () {
        releaseObjectUrl();
        if (removeFlag) removeFlag.value = "0";
        if (avatarInput) avatarInput.value = "";
        setPreview(initialSrc);
        showError("");
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

                if (data.status !== "success") return;

                // Linisin ang password fields — walang dahilan para
                // manatili ang plaintext sa DOM matapos i-save.
                if (passwordEl) passwordEl.value = "";
                if (confirmEl) confirmEl.value = "";
                if (avatarInput) avatarInput.value = "";
                if (removeFlag) removeFlag.value = "0";

                // Isabay ang topbar para hindi kailangang mag-refresh.
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
