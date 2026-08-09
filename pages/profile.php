<?php
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
<html lang="en" data-bs-theme="dark">

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
        ?>
        <div id="profilePage">
            <div class="profile-container">
                <h2 class="text-center mb-4">
                    <i class="bi bi-person-circle"></i> My Profile Settings
                </h2>

                <form id="profileForm">
                    <div class="mb-3">
                        <label>Full Name</label>
                        <input type="text" name="name" id="nameField" class="profile-input"
                            value="<?= htmlspecialchars($user['name'] ?? '') ?>" required>
                    </div>

                    <div class="mb-3">
                        <label>Email Address</label>
                        <input type="email" name="email" id="emailField" class="profile-input"
                            value="<?= htmlspecialchars($user['email'] ?? '') ?>" required>
                    </div>

                    <div class="mb-3">
                        <label>New Password (optional)</label>
                        <input type="password" name="password" class="profile-input"
                            placeholder="Leave blank to keep current password">
                    </div>

                    <button type="submit" class="profile-btn-save">Save Changes</button>
                </form>
            </div>
        </div>


    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <script src="../assets/js/profileUpdate.js"></script>
    <script src="../assets/js/comingSoon.js"></script>
    <script src="../assets/js/logout.js"></script>
    <script src="../assets/js/toggleSidebar.js"></script>
    <script src="../assets/js/datatables.js"></script>
    <script src="../assets/js/lock.js"></script>

</body>

</html>