<?php
// Ang avatar ay galing sa session (itinatakda ng login at ng
// crud/updateProfile.php). Kapag walang larawan — o luma pa ang
// session dahil hindi pa ulit nag-login mula nang idagdag ang
// feature — ang dating generic na icon ang ipinapakita.
//
// Kapag wala pa talaga ang susi (face login, o session na naunang
// buksan kaysa sa feature na ito), isang beses lang tayo magtatanong
// sa DB at ita-tago na sa session — mahal ang bawat query sa remote
// na database, at bawat page ay may topbar.
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
            // Wala pang `avatar` column — hindi pa napapatakbo ang
            // migrations/2026-08-10_add_user_avatar.sql. Icon muna.
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

    <!-- Brand — nakikita lang kapag off-canvas na ang sidebar (≤992px).
         Sa ganoong lapad ay nakatago ang buong sidebar, kaya wala nang
         kahit anong nagsasabi kung anong sistema ito; walang laman ang
         gitna ng topbar mula sa hamburger hanggang sa avatar.

         Sa desktop ay nananatili itong nakatago — nasa sidebar na ang
         logo at pangalan doon, at magiging ulit lang ito.

         Acronym lang ang ipinapakita rito — walang logo. Dalawang
         magkatabing bilog na larawan ang lalabas kung may logo (ang
         brand at ang avatar), at hindi naman nagsasabi ng pangalan ng
         sistema ang isang maliit na bilog. Ang teksto ang nagsasabi.

         Ang `$systemAcronym` ay galing sa includes/systemConfig.php, na
         isinasama ng includes/header.php sa bawat page na may topbar.
         May fallback pa rin kung sakaling isama ito kung saan wala ang
         header. -->
    <a class="tb-brand" href="../pages/dashboard.php">
        <span><?php echo htmlspecialchars($systemAcronym ?? 'Home'); ?></span>
    </a>

    <div class="dropdown">
        <div class="profile dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
            <img src="<?php echo htmlspecialchars($__avatarUrl); ?>" alt="Profile">
            <span class="profile-name"><?php echo $_SESSION['user_name']; ?></span>
        </div>
        <ul class="dropdown-menu dropdown-menu-end mt-2">
            <!-- User Info Header -->
            <li class="user-dropdown-header">
                <!-- `.tb-avatar` at hindi `.user-avatar`: may sariling
                     `.user-avatar { width: 32px }` ang management-pages.css
                     para sa mga hanay ng talahanayan, at naaabot nito ang
                     kahon na ito sa bawat page na naglo-load niyon. -->
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