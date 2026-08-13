<?php require_once __DIR__ . '/../includes/asset.php';

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
$admins   = mysqli_fetch_assoc(mysqli_query($conn, "SELECT COUNT(*) as count FROM users WHERE role = 'admin'"))['count'];

// The `avatar` column comes from migrations/2026-08-10_add_user_avatar.sql.
// It has not reached every server yet, so it is checked before being
// added to the SELECT — otherwise the whole page errors out.
$hasAvatarColumn = false;
try {
    $col = $conn->query("SHOW COLUMNS FROM users LIKE 'avatar'");
    $hasAvatarColumn = $col && $col->num_rows > 0;
} catch (Throwable $e) {
    $hasAvatarColumn = false;
}
$avatarSelect = $hasAvatarColumn ? "avatar," : "NULL as avatar,";

// ── Access summary per instructor ───────────────────────────
// One grouped query instead of a lookup per row, so the "3 of 11"
// badge costs nothing extra. Guarded the same way as the avatar
// column above: servers that have not run
// migrations/2026-08-13_add_user_permissions.sql yet simply show no
// badge rather than erroring out.
$permissionCounts = [];
$hasPermissionsTable = false;
try {
    $tbl = $conn->query("SHOW TABLES LIKE 'user_permissions_tbl'");
    $hasPermissionsTable = $tbl && $tbl->num_rows > 0;

    if ($hasPermissionsTable) {
        $counts = $conn->query("
            SELECT user_id, COUNT(*) AS granted
            FROM user_permissions_tbl
            GROUP BY user_id
        ");
        while ($row = $counts->fetch_assoc()) {
            $permissionCounts[(int)$row['user_id']] = (int)$row['granted'];
        }
    }
} catch (Throwable $e) {
    $hasPermissionsTable = false;
}

$totalPermissions = count(allPermissionKeys());
?>
<!doctype html>
<html lang="en">
<head>
    <?php include __DIR__ . "/../includes/header.php"; ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/settings.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/management-pages.css') ?>">
    <link rel="stylesheet" href="<?= asset('../assets/css/user-management.css') ?>">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
</head>
<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content users-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="users-hero">
            <div class="users-hero-icon"><i class="bi bi-people-fill"></i></div>
            <div class="users-hero-text">
                <h2>Manage Users</h2>
                <p>The accounts that can sign in to the system — admins and instructors.</p>
            </div>
            <button type="button" class="btn-add-user" id="openAddUser">
                <i class="bi bi-person-plus-fill"></i> Add User
            </button>
        </div>

        <!-- ── Stat Cards ── -->
        <div class="stat-grid users-stat-grid">
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
            <div class="stat-card cyan">
                <div class="stat-icon"><i class="bi bi-shield-lock-fill"></i></div>
                <div class="stat-label">Admins</div>
                <div class="stat-value" id="adminCount"><?= $admins ?></div>
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
                        SELECT id, name, email, role, $avatarSelect
                               IFNULL(status,'active') as status,
                               last_login
                        FROM users ORDER BY id DESC
                    ");
                    if (!$users_query) die("Query Error: " . mysqli_error($conn));
                    $counter = 1;
                    while ($user = mysqli_fetch_assoc($users_query)):
                        $user_status = !empty($user['status']) ? $user['status'] : 'active';
                        $initial     = strtoupper(substr($user['name'], 0, 1));
                        $isSelf      = $user['id'] == $_SESSION['user_id'];

                        $avatarPath = trim((string)($user['avatar'] ?? ''));
                        $avatarUrl  = $avatarPath !== '' && is_file(__DIR__ . '/../' . $avatarPath)
                            ? '../' . $avatarPath
                            : '';
                    ?>
                    <tr data-user-id="<?= $user['id'] ?>" data-role="<?= $user['role'] ?>" data-status="<?= $user_status ?>"
                        data-name="<?= htmlspecialchars($user['name'], ENT_QUOTES) ?>"
                        data-email="<?= htmlspecialchars($user['email'], ENT_QUOTES) ?>"
                        data-self="<?= $isSelf ? '1' : '0' ?>">
                        <td class="text-muted" style="font-size:.8rem"><?= $counter++ ?></td>
                        <td>
                            <div class="user-name">
                                <div class="user-avatar">
                                    <?php if ($avatarUrl !== ''): ?>
                                        <img src="<?= htmlspecialchars($avatarUrl) ?>" alt="">
                                    <?php else: ?>
                                        <?= $initial ?>
                                    <?php endif; ?>
                                </div>
                                <div>
                                    <strong><?= htmlspecialchars($user['name']) ?></strong>
                                    <?php if ($isSelf): ?>
                                        <span class="you-badge ms-1">You</span>
                                    <?php endif; ?>
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
                            <?php if ($hasPermissionsTable): ?>
                                <?php
                                // Most of the catalog is admin territory that
                                // starts off, so "not everything" is the norm
                                // and the count is what is actually useful.
                                // Only three states are worth distinguishing:
                                // nothing, everything, and a number.
                                $granted = $permissionCounts[(int)$user['id']] ?? 0;
                                $badge   = $granted === 0
                                    ? 'none'
                                    : ($granted >= $totalPermissions ? 'full' : 'limited');
                                ?>
                                <span class="access-badge <?= $badge ?>"
                                      title="<?= $granted ?> of <?= $totalPermissions ?> permissions granted">
                                    <i class="bi bi-shield-lock"></i>
                                    <?php if ($granted === 0): ?>
                                        No access
                                    <?php elseif ($badge === 'full'): ?>
                                        Full access
                                    <?php else: ?>
                                        <?= $granted ?> of <?= $totalPermissions ?>
                                    <?php endif; ?>
                                </span>
                            <?php endif; ?>
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
                            <div class="row-actions">
                                <button class="btn-edit" onclick="openEditUser(<?= $user['id'] ?>)">
                                    <i class="bi bi-pencil"></i> Edit
                                </button>
                                <?php if ($user['role'] !== 'admin'): ?>
                                    <button class="btn-access" onclick="openAccessModal(<?= $user['id'] ?>)">
                                        <i class="bi bi-shield-lock"></i> Access
                                    </button>
                                <?php endif; ?>
                                <?php if (!$isSelf): ?>
                                    <?php if ($user_status === 'active'): ?>
                                    <button class="btn-disable" onclick="toggleUserStatus(<?= $user['id'] ?>, 'disabled')">
                                        <i class="bi bi-person-x me-1"></i>Disable
                                    </button>
                                    <?php else: ?>
                                    <button class="btn-enable" onclick="toggleUserStatus(<?= $user['id'] ?>, 'active')">
                                        <i class="bi bi-person-check me-1"></i>Enable
                                    </button>
                                    <?php endif; ?>
                                <?php endif; ?>
                            </div>
                        </td>
                    </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>

    </div><!-- /content -->

    <!-- ════════════════════════════════════════════════════════
         ADD / EDIT USER

         Both share one modal: the fields are the same, only the
         password differs (required when new, optional when editing).
         That leaves one piece of markup to maintain.
         ════════════════════════════════════════════════════════ -->
    <div class="modal fade" id="userFormModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content user-modal">
                <form id="userForm">
                    <input type="hidden" name="user_id" id="formUserId" value="">

                    <div class="modal-header">
                        <div class="user-modal-icon"><i class="bi bi-person-plus-fill" id="formIcon"></i></div>
                        <div>
                            <h5 class="modal-title" id="formTitle">Add User</h5>
                            <small id="formSubtitle">Create a new account that can sign in to the system.</small>
                        </div>
                        <button type="button" class="btn-close btn-close-white ms-auto" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>

                    <div class="modal-body">
                        <div class="field">
                            <label for="formName">Full Name</label>
                            <div class="input-icon">
                                <i class="bi bi-person"></i>
                                <input type="text" name="name" id="formName" class="user-input"
                                    placeholder="e.g. Juan Dela Cruz" required>
                            </div>
                        </div>

                        <div class="field">
                            <label for="formEmail">Email Address</label>
                            <div class="input-icon">
                                <i class="bi bi-envelope"></i>
                                <input type="email" name="email" id="formEmail" class="user-input"
                                    placeholder="e.g. juan@bcc.edu.ph" required>
                            </div>
                        </div>

                        <div class="field">
                            <label for="formRole">Role</label>
                            <div class="role-picker">
                                <label class="role-option">
                                    <input type="radio" name="role" value="instructor" checked>
                                    <span>
                                        <i class="bi bi-person-badge"></i>
                                        <b>Instructor</b>
                                        <small>Attendance and their own sections only.</small>
                                    </span>
                                </label>
                                <label class="role-option">
                                    <input type="radio" name="role" value="admin">
                                    <span>
                                        <i class="bi bi-shield-fill"></i>
                                        <b>Admin</b>
                                        <small>Full access, including user management.</small>
                                    </span>
                                </label>
                            </div>
                            <small class="field-note" id="roleNote" style="display:none">
                                <i class="bi bi-info-circle"></i>
                                You cannot change your own role — this prevents locking yourself out.
                            </small>
                        </div>

                        <div class="field">
                            <label for="formPassword">
                                Password <span id="passwordHint" class="label-hint">(min. 8 characters)</span>
                            </label>
                            <div class="input-icon">
                                <i class="bi bi-lock"></i>
                                <input type="password" name="password" id="formPassword" class="user-input"
                                    placeholder="At least 8 characters" autocomplete="new-password">
                                <button type="button" class="input-eye" id="toggleFormPassword"
                                    aria-label="Show password"><i class="bi bi-eye"></i></button>
                            </div>
                            <small class="field-error" id="formError"></small>
                        </div>
                    </div>

                    <div class="modal-footer">
                        <button type="button" class="btn-ghost" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="btn-save" id="formSubmit">
                            <i class="bi bi-check2-circle"></i> Save User
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- ════════════════════════════════════════════════════════
         MANAGE ACCESS

         The catalog is rendered here from PERMISSION_CATALOG rather
         than being rebuilt in JavaScript: the labels and grouping
         then have exactly one definition (includes/permissions.php),
         and the modal cannot drift out of step with what the server
         actually enforces. The JS only ticks the boxes.
         ════════════════════════════════════════════════════════ -->
    <div class="modal fade" id="accessModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered modal-lg">
            <div class="modal-content user-modal access-modal">
                <form id="accessForm">
                    <input type="hidden" name="user_id" id="accessUserId" value="">

                    <div class="modal-header">
                        <div class="user-modal-icon"><i class="bi bi-shield-lock"></i></div>
                        <div>
                            <h5 class="modal-title">Manage Access</h5>
                            <small>What <strong id="accessUserName">this instructor</strong> is allowed to do.</small>
                        </div>
                        <button type="button" class="btn-close btn-close-white ms-auto" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>

                    <div class="modal-body">
                        <div class="access-toolbar">
                            <span class="access-count" id="accessCount">0 of <?= $totalPermissions ?> selected</span>
                            <div class="access-toolbar-actions">
                                <button type="button" class="btn-ghost-sm" id="accessSelectAll">
                                    <i class="bi bi-check2-all"></i> Select all
                                </button>
                                <button type="button" class="btn-ghost-sm" id="accessClearAll">
                                    <i class="bi bi-x-lg"></i> Clear all
                                </button>
                            </div>
                        </div>

                        <div class="access-loading" id="accessLoading">
                            <i class="bi bi-hourglass-split"></i> Loading current access...
                        </div>

                        <div class="access-groups" id="accessGroups">
                            <?php foreach (PERMISSION_CATALOG as $groupKey => $group): ?>
                                <fieldset class="access-group" data-group="<?= htmlspecialchars($groupKey) ?>">
                                    <legend class="access-group-head">
                                        <i class="bi <?= htmlspecialchars($group['icon']) ?>"></i>
                                        <span><?= htmlspecialchars($group['label']) ?></span>
                                        <button type="button" class="access-group-toggle" data-group-toggle="<?= htmlspecialchars($groupKey) ?>">
                                            Toggle
                                        </button>
                                    </legend>

                                    <?php foreach ($group['items'] as $key => $item): ?>
                                        <label class="perm-row">
                                            <input type="checkbox" class="perm-check" name="permissions[]"
                                                   value="<?= htmlspecialchars($key) ?>">
                                            <span class="perm-box"><i class="bi bi-check"></i></span>
                                            <span class="perm-text">
                                                <b><i class="bi <?= htmlspecialchars($item['icon']) ?>"></i> <?= htmlspecialchars($item['label']) ?></b>
                                                <small><?= htmlspecialchars($item['note']) ?></small>
                                            </span>
                                        </label>
                                    <?php endforeach; ?>
                                </fieldset>
                            <?php endforeach; ?>
                        </div>

                        <p class="access-note" id="accessEmptyNote">
                            <i class="bi bi-exclamation-triangle"></i>
                            With nothing selected this instructor can still sign in, but will
                            only see the dashboard.
                        </p>
                        <small class="field-error" id="accessError"></small>
                    </div>

                    <div class="modal-footer">
                        <button type="button" class="btn-ghost" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="btn-save" id="accessSubmit">
                            <i class="bi bi-check2-circle"></i> Save Access
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <?php include __DIR__ . "/../includes/footer.php"; ?>

    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/lock.js') ?>"></script>
    <script src="<?= asset('../assets/js/systemConfig.js') ?>"></script>
    <script src="<?= asset('../assets/js/userManagement.js') ?>"></script>
</body>
</html>
