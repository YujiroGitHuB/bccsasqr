<!-- User Management Modal -->
 
<div class="modal fade" id="userManagementModal" tabindex="-1" aria-labelledby="userManagementModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content bg-dark text-white border-0">
            <div class="modal-header border-secondary">
                <h5 class="modal-title" id="userManagementModalLabel">
                    <i class="bi bi-people-fill text-info"></i> User Management
                </h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <!-- Filter Section -->
                <div class="row mb-3">
                    <div class="col-md-4">
                        <input type="text" id="searchUser" class="form-control" placeholder="Search users...">
                    </div>
                    <div class="col-md-3">
                        <select id="filterRole" class="form-select">
                            <option value="">All Roles</option>
                            <option value="admin">Admin</option>
                            <option value="instructor">Instructor</option>
                        </select>
                    </div>
                    <div class="col-md-3">
                        <select id="filterStatus" class="form-select">
                            <option value="">All Status</option>
                            <option value="active">Active</option>
                            <option value="disabled">Disabled</option>
                        </select>
                    </div>
                    <div class="col-md-2">
                        <button class="btn btn-secondary w-100" onclick="resetFilters()">
                            <i class="bi bi-arrow-clockwise"></i> Reset
                        </button>
                    </div>
                </div>

                <!-- Users Table -->
                <div class="table-responsive">
                    <table id="usersTable" class="table table-dark table-striped table-hover">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Name</th>
                                <th>Email</th>
                                <th>Role</th>
                                <th>Status</th>
                                <th>Created</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php
                            $users_query = mysqli_query($conn, "
                                SELECT id, name, email, role, status, created_at 
                                FROM users 
                                ORDER BY created_at DESC
                            ");
                            
                            $counter = 1;
                            while ($user = mysqli_fetch_assoc($users_query)):
                                $statusClass = $user['status'] === 'active' ? 'success' : 'danger';
                                $statusIcon = $user['status'] === 'active' ? 'check-circle-fill' : 'x-circle-fill';
                                $roleClass = $user['role'] === 'admin' ? 'warning' : 'info';
                            ?>
                                <tr data-user-id="<?= $user['id'] ?>" data-role="<?= $user['role'] ?>" data-status="<?= $user['status'] ?>">
                                    <td><?= $counter++ ?></td>
                                    <td>
                                        <i class="bi bi-person-circle text-primary"></i>
                                        <strong><?= htmlspecialchars($user['name']) ?></strong>
                                    </td>
                                    <td><?= htmlspecialchars($user['email']) ?></td>
                                    <td>
                                        <span class="badge bg-<?= $roleClass ?>">
                                            <i class="bi bi-<?= $user['role'] === 'admin' ? 'shield-fill' : 'person-badge' ?>"></i>
                                            <?= ucfirst($user['role']) ?>
                                        </span>
                                    </td>
                                    <td>
                                        <span class="badge bg-<?= $statusClass ?>">
                                            <i class="bi bi-<?= $statusIcon ?>"></i>
                                            <?= ucfirst($user['status']) ?>
                                        </span>
                                    </td>
                                    <td><?= date('M d, Y', strtotime($user['created_at'])) ?></td>
                                    <td>
                                        <?php if ($user['id'] != $_SESSION['user_id']): // Can't disable yourself ?>
                                            <?php if ($user['status'] === 'active'): ?>
                                                <button class="btn btn-sm btn-danger" onclick="toggleUserStatus(<?= $user['id'] ?>, 'disabled', '<?= htmlspecialchars($user['name']) ?>')">
                                                    <i class="bi bi-person-x"></i> Disable
                                                </button>
                                            <?php else: ?>
                                                <button class="btn btn-sm btn-success" onclick="toggleUserStatus(<?= $user['id'] ?>, 'active', '<?= htmlspecialchars($user['name']) ?>')">
                                                    <i class="bi bi-person-check"></i> Enable
                                                </button>
                                            <?php endif; ?>
                                        <?php else: ?>
                                            <span class="badge bg-secondary">Current User</span>
                                        <?php endif; ?>
                                    </td>
                                </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                </div>

                <!-- Summary Stats -->
                <div class="row mt-4">
                    <div class="col-md-4">
                        <div class="card bg-success bg-opacity-10 border-success">
                            <div class="card-body text-center">
                                <h3 class="text-success" id="activeCount">
                                    <?php 
                                    $active = mysqli_query($conn, "SELECT COUNT(*) as count FROM users WHERE status = 'active'");
                                    echo mysqli_fetch_assoc($active)['count'];
                                    ?>
                                </h3>
                                <small class="text-success">Active Users</small>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card bg-danger bg-opacity-10 border-danger">
                            <div class="card-body text-center">
                                <h3 class="text-danger" id="disabledCount">
                                    <?php 
                                    $disabled = mysqli_query($conn, "SELECT COUNT(*) as count FROM users WHERE status = 'disabled'");
                                    echo mysqli_fetch_assoc($disabled)['count'];
                                    ?>
                                </h3>
                                <small class="text-danger">Disabled Users</small>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="card bg-info bg-opacity-10 border-info">
                            <div class="card-body text-center">
                                <h3 class="text-info" id="totalCount">
                                    <?php 
                                    $total = mysqli_query($conn, "SELECT COUNT(*) as count FROM users");
                                    echo mysqli_fetch_assoc($total)['count'];
                                    ?>
                                </h3>
                                <small class="text-info">Total Users</small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-footer border-secondary">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
            </div>
        </div>
    </div>
</div>