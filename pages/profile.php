<?php require_once __DIR__ . '/../includes/asset.php';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";

// Everyone with an account gets their own profile — this page was
// admin-only, which left instructors with no way to change their own
// password even though crud/updateProfile.php already accepted them.
// It is not a permission: the endpoint is hard-scoped to
// $_SESSION['user_id'], so there is nobody else to edit and nothing to
// escalate. Only the email is held back — see $canChangeEmail below.
$canChangeEmail = isAdmin();
include __DIR__ . "/../includes/db_connect.php";
// Get system settings (optional)
$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system = mysqli_fetch_assoc($systemQuery);
?>

<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>

    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>
        <?php
        // Get logged-in user
        $userId = $_SESSION['user_id'] ?? 0;
        $userQuery = mysqli_query($conn, "SELECT * FROM users WHERE id='$userId'");
        $user = mysqli_fetch_assoc($userQuery);

        // The `avatar` column comes from the
        // 2026-08-10_add_user_avatar.sql migration. The ?? keeps the
        // page from breaking on a server where it has not been run.
        $avatarPath = trim((string)($user['avatar'] ?? ''));
        $avatarUrl  = $avatarPath !== '' && is_file(__DIR__ . '/../' . $avatarPath)
            ? '../' . $avatarPath . '?v=' . @filemtime(__DIR__ . '/../' . $avatarPath)
            : '';

        // Both columns have to agree before the card claims a face is on
        // file: crud/get_face_users.php only serves rows where the flag is
        // set AND the descriptor is non-empty, so anything else would show
        // "enrolled" for a face that face login will never actually match.
        $hasFace = !empty($user['face_enabled']) && trim((string)($user['face_descriptor'] ?? '')) !== '';

        // Initials bilang fallback — pareho ng lohika sa topBar.php.
        $initials = '';
        foreach (explode(' ', trim((string)($user['name'] ?? ''))) as $part) {
            if ($part === '') continue;
            $initials .= strtoupper(substr($part, 0, 1));
            if (strlen($initials) >= 2) break;
        }
        if ($initials === '') $initials = '?';

        $role      = ucfirst((string)($user['role'] ?? 'user'));
        $status    = strtolower((string)($user['status'] ?? 'active'));
        $lastLogin = !empty($user['last_login'])
            ? date('M d, Y · g:i A', strtotime($user['last_login']))
            : 'No record yet';
        ?>
        <div id="profilePage">

            <div class="profile-head">
                <h2><i class="bi bi-person-gear"></i> My Profile Settings</h2>
                <p>Update your account details, password, and profile picture.</p>
            </div>

            <form id="profileForm" class="profile-shell" enctype="multipart/form-data" novalidate>

                <!-- ── Kaliwa: avatar at buod ng account ──────────── -->
                <aside class="profile-card profile-side">
                    <div class="profile-cover"></div>

                    <div class="avatar-block <?= $avatarUrl !== '' ? 'has-photo' : '' ?>" id="avatarBlock">
                        <div class="avatar-ring">
                            <!-- No `src=""` when there is no photo — in some
                                 browsers that fetches the page URL itself as an
                                 image, wasting a request. -->
                            <img <?= $avatarUrl !== '' ? 'src="' . htmlspecialchars($avatarUrl) . '"' : '' ?>
                                alt="Profile picture" class="avatar-photo" id="avatarPreview">
                            <span class="avatar-initials" id="avatarInitials"><?= htmlspecialchars($initials) ?></span>
                        </div>
                        <button type="button" class="avatar-edit" id="avatarPickBtn"
                            title="Change profile picture" aria-label="Change profile picture">
                            <i class="bi bi-camera-fill"></i>
                        </button>
                    </div>

                    <!-- The file input sits inside the form so it is carried
                         in "Save Changes"' FormData — one submit only. -->
                    <input type="file" name="avatar" id="avatarInput"
                        accept="image/jpeg,image/png,image/webp" hidden>
                    <input type="hidden" name="remove_avatar" id="removeAvatarFlag" value="0">

                    <h3 class="profile-name-lg" id="profileNameLabel"><?= htmlspecialchars($user['name'] ?? '') ?></h3>
                    <span class="profile-role-badge">
                        <i class="bi bi-shield-check"></i> <?= htmlspecialchars($role) ?>
                    </span>

                    <div class="avatar-actions">
                        <button type="button" class="profile-btn-ghost" id="avatarUploadBtn">
                            <i class="bi bi-upload"></i> Upload Photo
                        </button>
                        <button type="button" class="profile-btn-ghost danger" id="avatarRemoveBtn"
                            <?= $avatarUrl === '' ? 'disabled' : '' ?>>
                            <i class="bi bi-trash3"></i> Remove
                        </button>
                    </div>
                    <p class="avatar-hint">JPG, PNG, or WEBP · max 2 MB</p>

                    <ul class="profile-meta">
                        <li>
                            <span><i class="bi bi-activity"></i> Status</span>
                            <b class="status-pill <?= $status === 'disabled' ? 'off' : 'on' ?>">
                                <?= htmlspecialchars(ucfirst($status)) ?>
                            </b>
                        </li>
                        <li>
                            <span><i class="bi bi-clock-history"></i> Last login</span>
                            <b><?= htmlspecialchars($lastLogin) ?></b>
                        </li>
                        <li>
                            <span><i class="bi bi-hash"></i> User ID</span>
                            <b><?= (int)($user['id'] ?? 0) ?></b>
                        </li>
                    </ul>
                </aside>

                <!-- ── Right: the fields ──────────────────────────── -->
                <section class="profile-card profile-main">

                    <div class="profile-section-title">
                        <i class="bi bi-person-vcard"></i>
                        <div>
                            <h4>Account Details</h4>
                            <small>This is the name shown in the topbar and on records.</small>
                        </div>
                    </div>

                    <div class="profile-grid">
                        <div class="field">
                            <label for="nameField">Full Name</label>
                            <div class="input-icon">
                                <i class="bi bi-person"></i>
                                <input type="text" name="name" id="nameField" class="profile-input"
                                    value="<?= htmlspecialchars($user['name'] ?? '') ?>"
                                    autocomplete="name" required>
                            </div>
                        </div>

                        <div class="field">
                            <label for="emailField">Email Address</label>
                            <div class="input-icon">
                                <i class="bi bi-envelope"></i>
                                <?php
                                // readonly, not disabled: a disabled input is not
                                // submitted at all, and the endpoint requires the
                                // field to be present. crud/updateProfile.php
                                // rejects a changed value anyway — this is only so
                                // the field does not invite the attempt.
                                ?>
                                <input type="email" name="email" id="emailField" class="profile-input"
                                    value="<?= htmlspecialchars($user['email'] ?? '') ?>"
                                    autocomplete="email" required
                                    <?= $canChangeEmail ? '' : 'readonly' ?>>
                            </div>
                            <?php if (!$canChangeEmail): ?>
                                <small class="field-note">
                                    <i class="bi bi-lock"></i>
                                    This is your sign-in address. Contact the administrator to change it.
                                </small>
                            <?php endif; ?>
                        </div>
                    </div>

                    <hr class="profile-divider">

                    <div class="profile-section-title">
                        <i class="bi bi-key"></i>
                        <div>
                            <h4>Change Password</h4>
                            <small>Leave blank if you do not want to change your password.</small>
                        </div>
                    </div>

                    <div class="profile-grid">
                        <div class="field">
                            <label for="passwordField">New Password</label>
                            <div class="input-icon">
                                <i class="bi bi-lock"></i>
                                <input type="password" name="password" id="passwordField" class="profile-input"
                                    placeholder="At least 8 characters" autocomplete="new-password">
                                <button type="button" class="input-eye" id="togglePassword"
                                    aria-label="Show password"><i class="bi bi-eye"></i></button>
                            </div>
                        </div>

                        <div class="field">
                            <label for="confirmField">Confirm New Password</label>
                            <div class="input-icon">
                                <i class="bi bi-lock-fill"></i>
                                <input type="password" id="confirmField" class="profile-input"
                                    placeholder="Re-type the new password" autocomplete="new-password">
                            </div>
                            <small class="field-error" id="passwordError"></small>
                        </div>
                    </div>

                    <hr class="profile-divider">

                    <div class="profile-section-title">
                        <i class="bi bi-person-bounding-box"></i>
                        <div>
                            <h4>Face Recognition</h4>
                            <small>Sign in by looking at the camera instead of typing your password.</small>
                        </div>
                    </div>

                    <?php
                    /* data-enrolled is the single source of truth for this
                       block's state. assets/js/profileFace.js flips it after a
                       capture or a remove, and every label below is redrawn
                       from it, so the markup and the script never disagree
                       about whether a face is on file. */
                    ?>
                    <div class="face-enroll" id="faceEnroll" data-enrolled="<?= $hasFace ? '1' : '0' ?>">
                        <div class="face-enroll-info">
                            <span class="face-enroll-badge" id="faceEnrollBadge"></span>
                            <small class="face-enroll-note" id="faceEnrollNote"></small>
                        </div>

                        <div class="face-enroll-actions">
                            <button type="button" class="profile-btn-ghost" id="faceEnrollBtn">
                                <i class="bi bi-camera"></i> <span id="faceEnrollBtnText">Set up</span>
                            </button>
                            <button type="button" class="profile-btn-ghost danger" id="faceRemoveBtn">
                                <i class="bi bi-trash3"></i> Remove
                            </button>
                        </div>
                    </div>

                    <?php
                    /* Both ride along in the same FormData that
                       assets/js/profileUpdate.js already builds from this
                       form, so nothing new posts anywhere — crud/updateProfile.php
                       simply gained two more fields to read. */
                    ?>
                    <input type="hidden" name="faceDescriptor" id="faceDescriptorField" value="">
                    <input type="hidden" name="remove_face" id="removeFaceField" value="0">

                    <hr class="profile-divider">

                    <div class="profile-section-title">
                        <i class="bi bi-shield-lock"></i>
                        <div>
                            <h4>Confirm It's You</h4>
                            <small>
                                Needed only when you change your password or your face — the two
                                ways into this account. Leave it blank for anything else.
                            </small>
                        </div>
                    </div>

                    <div class="profile-grid">
                        <div class="field">
                            <label for="currentPasswordField">Current Password</label>
                            <div class="input-icon">
                                <i class="bi bi-shield-lock"></i>
                                <input type="password" name="current_password" id="currentPasswordField"
                                    class="profile-input" placeholder="Your current password"
                                    autocomplete="current-password">
                            </div>
                            <small class="field-error" id="currentPasswordError"></small>
                        </div>
                    </div>

                    <div class="profile-actions">
                        <button type="reset" class="profile-btn-ghost" id="profileResetBtn">
                            <i class="bi bi-arrow-counterclockwise"></i> Reset
                        </button>
                        <button type="submit" class="profile-btn-save" id="profileSaveBtn">
                            <i class="bi bi-check2-circle"></i> Save Changes
                        </button>
                    </div>
                </section>
            </form>

            <?php
            /* Outside #profileForm but still inside #profilePage, and both
               halves of that matter. Nested in the form, the dialog's buttons
               would join the form's submit scope. Outside #profilePage, its
               .profile-btn-ghost / .profile-btn-save would lose their styling
               entirely — every button rule in main.css is scoped to that id.

               Ids are prefixed pf- so none of them collide with the enrolment
               modal on reg.php, which assets/js/faceRecognition.js binds to by
               bare id. */
            ?>
            <div class="pf-face-modal" id="pfFaceModal" hidden>
                <div class="pf-face-dialog" role="dialog" aria-modal="true" aria-labelledby="pfFaceTitle">
                    <div class="pf-face-head">
                        <h3 id="pfFaceTitle">
                            <i class="bi bi-person-bounding-box"></i>
                            <span id="pfFaceTitleText">Set up face recognition</span>
                        </h3>
                        <button type="button" class="pf-face-close" id="pfFaceClose" aria-label="Close">
                            <i class="bi bi-x-lg"></i>
                        </button>
                    </div>

                    <div class="pf-face-stage">
                        <video id="pfFaceVideo" autoplay muted playsinline></video>
                        <canvas id="pfFaceCanvas"></canvas>
                    </div>

                    <div class="pf-face-pips" id="pfFacePips" aria-hidden="true"></div>

                    <p class="pf-face-status" id="pfFaceStatus">Starting camera…</p>

                    <div class="pf-face-actions">
                        <button type="button" class="profile-btn-ghost" id="pfFaceCancel">Cancel</button>
                        <button type="button" class="profile-btn-save" id="pfFaceCapture" disabled>
                            <i class="bi bi-camera"></i> Capture
                        </button>
                    </div>
                </div>
            </div>
        </div>


    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <!-- face-api.js, same version the login and registration pages pin. -->
    <script defer src="https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js"></script>
    <script src="<?= asset('../assets/js/profileFace.js') ?>"></script>

    <script src="<?= asset('../assets/js/profileUpdate.js') ?>"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>

</body>

</html>
