<?php require_once __DIR__ . '/../includes/asset.php';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if(!isAdmin()){
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
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
                                <input type="email" name="email" id="emailField" class="profile-input"
                                    value="<?= htmlspecialchars($user['email'] ?? '') ?>"
                                    autocomplete="email" required>
                            </div>
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
        </div>


    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <script src="<?= asset('../assets/js/profileUpdate.js') ?>"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>

</body>

</html>
