<!-- Topbar with Toggle (Left) and Profile (Right) -->
<div class="topbar">
    <button class="toggle-btn" onclick="toggleSidebar()"><i class="bi bi-list"></i></button>

    <div class="dropdown">
        <div class="profile dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
            <img src="https://cdn-icons-png.flaticon.com/128/15329/15329400.png" alt="Profile">
            <span class="profile-name"><?php echo $_SESSION['user_name']; ?></span>
        </div>
        <ul class="dropdown-menu dropdown-menu-end mt-2">
            <!-- User Info Header -->
            <li class="user-dropdown-header">
                <div class="d-flex align-items-center gap-3 p-3">
                    <div class="user-avatar">
                        <div class="avatar-circle">
                            <?php
                            // Get initials from name
                            $name_parts = explode(' ', $_SESSION['user_name']);
                            $initials = '';
                            foreach ($name_parts as $part) {
                                $initials .= strtoupper(substr($part, 0, 1));
                                if (strlen($initials) >= 2) break;
                            }
                            echo $initials;
                            ?>
                        </div>
                        <span class="avatar-status"></span>
                    </div>
                    <div class="user-info">
                        <h6 class="mb-0 fw-bold text-white"><?php echo $_SESSION['user_name']; ?></h6>
                        <small class="text-white-50">
                            <i class="bi bi-shield-check me-1"></i>
                            <?php echo ucfirst($_SESSION['role']); ?>
                        </small>
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