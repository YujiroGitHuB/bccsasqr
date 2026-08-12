<?php
// The avatar comes from the session (set by login and by
// crud/updateProfile.php). With no photo — or with a stale session,
// because the user has not signed in again since the feature was
// added — the old generic icon is shown.
//
// When the key is genuinely absent (face login, or a session opened
// before this feature existed), the DB is asked once and the result
// cached in the session — every query against a remote database is
// expensive, and every page has a topbar.
if (!array_key_exists('user_avatar', $_SESSION) && !empty($_SESSION['user_id'])) {
    $_SESSION['user_avatar'] = null;
    if (isset($conn) && $conn instanceof mysqli) {
        try {
            $__q = $conn->prepare("SELECT avatar FROM users WHERE id = ?");
            $__q->bind_param("i", $_SESSION['user_id']);
            $__q->execute();
            $_SESSION['user_avatar'] = $__q->get_result()->fetch_assoc()['avatar'] ?? null;
            $__q->close();
        } catch (Throwable $e) {
            // No `avatar` column yet —
            // migrations/2026-08-10_add_user_avatar.sql has not been
            // run. Fall back to the icon.
        }
    }
}

$__avatar     = trim((string)($_SESSION['user_avatar'] ?? ''));
$__avatarFile = $__avatar !== '' ? __DIR__ . '/../' . $__avatar : '';
$__avatarUrl  = $__avatarFile !== '' && is_file($__avatarFile)
    ? '../' . $__avatar . '?v=' . @filemtime($__avatarFile)
    : 'https://cdn-icons-png.flaticon.com/128/15329/15329400.png';
?>
<!-- Topbar with Toggle (Left), Brand (Center) and Profile (Right) -->
<div class="topbar">
    <button class="toggle-btn" onclick="toggleSidebar()"><i class="bi bi-list"></i></button>

    <!-- Brand — only visible once the sidebar goes off-canvas (≤992px).
         At those widths the whole sidebar is hidden, so nothing says
         which system this is; the middle of the topbar is empty from
         the hamburger across to the avatar.

         It stays hidden on desktop — the logo and name are already in
         the sidebar there, and this would only repeat them.

         Only the acronym is shown here — no logo. A logo would put two
         round images side by side (the brand and the avatar), and a
         small circle does not tell you the system's name. The text
         does.

         `$systemAcronym` comes from includes/systemConfig.php, which
         includes/header.php pulls into every page that has a topbar.
         The fallback is there in case this is included somewhere the
         header is not. -->
    <a class="tb-brand" href="../pages/dashboard.php">
        <span><?php echo htmlspecialchars($systemAcronym ?? 'Home'); ?></span>
    </a>

    <!-- Theme toggle. Sits beside the avatar rather than inside the
         dropdown: it is a switch, not a destination, and burying a
         one-click control behind a menu makes it a two-click one.
         The icon is filled in by assets/js/theme.js once it knows
         which theme is active — rendering one here would show the
         wrong icon for a moment on every load. -->
    <button class="tb-theme" id="themeToggle" type="button"
            aria-label="Switch between light and dark" title="Switch theme">
        <i class="bi" aria-hidden="true"></i>
    </button>

    <div class="dropdown">
        <div class="profile dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
            <img src="<?php echo htmlspecialchars($__avatarUrl); ?>" alt="Profile">
            <span class="profile-name"><?php echo $_SESSION['user_name']; ?></span>
        </div>
        <ul class="dropdown-menu dropdown-menu-end mt-2">
            <!-- User Info Header -->
            <li class="user-dropdown-header">
                <!-- `.tb-avatar`, not `.user-avatar`: management-pages.css
                     has its own `.user-avatar { width: 32px }` for table
                     rows, and it reaches this box on every page that
                     loads it. -->
                <div class="tb-user">
                    <div class="tb-avatar">
                        <div class="avatar-circle">
                            <?php if ($__avatarFile !== '' && is_file($__avatarFile)) { ?>
                                <img src="<?php echo htmlspecialchars($__avatarUrl); ?>" alt="">
                            <?php } else {
                                // Get initials from name
                                $name_parts = explode(' ', $_SESSION['user_name']);
                                $initials = '';
                                foreach ($name_parts as $part) {
                                    $initials .= strtoupper(substr($part, 0, 1));
                                    if (strlen($initials) >= 2) break;
                                }
                                echo $initials;
                            } ?>
                        </div>
                        <span class="tb-status" title="Online"></span>
                    </div>
                    <div class="tb-user-info">
                        <h6 title="<?php echo htmlspecialchars($_SESSION['user_name']); ?>">
                            <?php echo htmlspecialchars($_SESSION['user_name']); ?>
                        </h6>
                        <span class="tb-role">
                            <i class="bi bi-shield-check"></i>
                            <?php echo htmlspecialchars(ucfirst($_SESSION['role'])); ?>
                        </span>
                    </div>
                </div>
            </li>
            <li>
                <hr class="dropdown-divider my-2">
            </li>
            <?php if (isAdmin()) { ?>
                <li><a class="dropdown-item" href="../pages/profile.php"><i class="bi bi-person me-2"></i>My Profile</a></li>
                <li><a class="dropdown-item" href="../pages/settings.php"><i class="bi bi-gear me-2"></i>Settings</a></li>
                <li>
                    <hr class="dropdown-divider">
                </li>
            <?php } ?>
            <li>
                <a class="dropdown-item text-danger" href="#" onclick="confirmLogout()">
                    <i class="bi bi-box-arrow-right me-2"></i>Logout
                </a>
            </li>
        </ul>

    </div>
</div>