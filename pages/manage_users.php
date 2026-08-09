<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
if (!isAdmin()) {
    header("Location: dashboard.php");
    exit;
}
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

$systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
$system        = mysqli_fetch_assoc($systemQuery);
$systemName    = $system['system_name']    ?? '';
$systemAcronym = $system['system_acronym'] ?? '';
$systemLogo    = $system['logo']           ?? '';

$active   = mysqli_fetch_assoc(mysqli_query($conn, "SELECT COUNT(*) as count FROM users WHERE IFNULL(status,'active') = 'active'"))['count'];
$disabled = mysqli_fetch_assoc(mysqli_query($conn, "SELECT COUNT(*) as count FROM users WHERE status = 'disabled'"))['count'];
$total    = mysqli_fetch_assoc(mysqli_query($conn, "SELECT COUNT(*) as count FROM users"))['count'];
?>
<!doctype html>
<html lang="en" data-bs-theme="dark">
<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="../assets/css/settings.css">
    <link rel="stylesheet" href="../assets/css/management-pages.css">
    <link rel="stylesheet" href="../assets/css/user-management.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
</head>
<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="users-page-header">
            <h2><i class="bi bi-people-fill"></i> Manage Users</h2>
        </div>

        <!-- ── Stat Cards ── -->
        <div class="stat-grid">
            <div class="stat-card green">
                <div class="stat-icon"><i class="bi bi-person-check-fill"></i></div>
                <div class="stat-label">Active Users</div>
                <div class="stat-value" id="activeCount"><?= $active ?></div>
            </div>
            <div class="stat-card red">
                <div class="stat-icon"><i class="bi bi-person-x-fill"></i></div>
                <div class="stat-label">Disabled Users</div>
                <div class="stat-value" id="disabledCount"><?= $disabled ?></div>
            </div>
            <div class="stat-card blue">
                <div class="stat-icon"><i class="bi bi-people-fill"></i></div>
                <div class="stat-label">Total Users</div>
                <div class="stat-value" id="totalCount"><?= $total ?></div>
            </div>
        </div>

        <!-- ── Filter Bar ── -->
        <div class="filter-bar">
            <div class="flex-grow-1" style="min-width:180px">
                <input type="text" id="searchUser" class="form-control" placeholder="🔍  Search name or email...">
            </div>
            <div style="min-width:140px">
                <select id="filterRole" class="form-select">
                    <option value="">All Roles</option>
                    <option value="admin">Admin</option>
                    <option value="instructor">Instructor</option>
                </select>
            </div>
            <div style="min-width:140px">
                <select id="filterStatus" class="form-select">
                    <option value="">All Status</option>
                    <option value="active">Active</option>
                    <option value="disabled">Disabled</option>
                </select>
            </div>
            <button class="btn-reset" onclick="resetFilters()">
                <i class="bi bi-arrow-clockwise me-1"></i> Reset
            </button>
        </div>

        <!-- ── Table ── -->
        <div class="section-header">
            <span class="section-title">User Accounts</span>
        </div>

        <div class="table-card">
            <table id="usersTable" class="table mb-0">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>User</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Last Login</th>
                        <th class="text-center">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $users_query = mysqli_query($conn, "
                        SELECT id, name, email, role,
                               IFNULL(status,'active') as status,
                               last_login
                        FROM users ORDER BY id DESC
                    ");
                    if (!$users_query) die("Query Error: " . mysqli_error($conn));
                    $counter = 1;
                    while ($user = mysqli_fetch_assoc($users_query)):
                        $user_status = !empty($user['status']) ? $user['status'] : 'active';
                        $initial     = strtoupper(substr($user['name'], 0, 1));
                    ?>
                    <tr data-user-id="<?= $user['id'] ?>" data-role="<?= $user['role'] ?>" data-status="<?= $user_status ?>">
                        <td class="text-muted" style="font-size:.8rem"><?= $counter++ ?></td>
                        <td>
                            <div class="user-name">
                                <div class="user-avatar"><?= $initial ?></div>
                                <div>
                                    <strong><?= htmlspecialchars($user['name']) ?></strong>
                                </div>
                            </div>
                        </td>
                        <td style="color:rgba(255,255,255,.55); font-size:.83rem"><?= htmlspecialchars($user['email']) ?></td>
                        <td>
                            <?php if ($user['role'] === 'admin'): ?>
                            <span class="role-badge role-admin">
                                <i class="bi bi-shield-fill"></i> Admin
                            </span>
                            <?php else: ?>
                            <span class="role-badge role-instructor">
                                <i class="bi bi-person-badge"></i> Instructor
                            </span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php if ($user_status === 'active'): ?>
                            <span class="status-badge status-active">
                                <i class="bi bi-check-circle-fill"></i> Active
                            </span>
                            <?php else: ?>
                            <span class="status-badge status-disabled">
                                <i class="bi bi-x-circle-fill"></i> Disabled
                            </span>
                            <?php endif; ?>
                        </td>
                        <td style="font-size:.82rem; color:rgba(255,255,255,.4)">
                            <?php if (!empty($user['last_login'])): ?>
                                <i class="bi bi-clock me-1" style="color:#60a5fa"></i>
                                <?= date('M d, Y g:i A', strtotime($user['last_login'])) ?>
                            <?php else: ?>
                                <span style="color:rgba(255,255,255,.2)"><i class="bi bi-dash-circle me-1"></i>Never</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-center">
                            <?php if ($user['id'] != $_SESSION['user_id']): ?>
                                <?php if ($user_status === 'active'): ?>
                                <button class="btn-disable" onclick="toggleUserStatus(<?= $user['id'] ?>, 'disabled', '<?= addslashes(htmlspecialchars($user['name'])) ?>')">
                                    <i class="bi bi-person-x me-1"></i>Disable
                                </button>
                                <?php else: ?>
                                <button class="btn-enable" onclick="toggleUserStatus(<?= $user['id'] ?>, 'active', '<?= addslashes(htmlspecialchars($user['name'])) ?>')">
                                    <i class="bi bi-person-check me-1"></i>Enable
                                </button>
                                <?php endif; ?>
                            <?php else: ?>
                                <span class="you-badge"><i class="bi bi-person-fill me-1"></i>You</span>
                            <?php endif; ?>
                        </td>
                    </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>

    </div><!-- /content -->

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="../assets/js/comingSoon.js"></script>
    <script src="../assets/js/logout.js"></script>
    <script src="../assets/js/toggleSidebar.js"></script>
    <script src="../assets/js/datatables.js"></script>
    <script src="../assets/js/lock.js"></script>
    <script src="../assets/js/systemConfig.js"></script>
    <script src="../assets/js/userManagement.js"></script>
</body>
</html>