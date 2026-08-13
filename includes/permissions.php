<?php
// ============================================================
//  ROLES AND PER-USER PERMISSIONS
//
//  isAdmin()/isStaff() used to be the whole access-control story:
//  two roles, and what each could do was hard-coded at every call
//  site. There was no way for an admin to say "this instructor may
//  record attendance but not delete it".
//
//  can('attendance.delete') answers that instead. Admins always
//  pass — a role check short-circuits before the table is even
//  read, so an admin cannot be locked out of their own system.
//  For instructors the answer comes from user_permissions_tbl
//  (migrations/2026-08-13_add_user_permissions.sql), where one row
//  means one granted permission.
//
//  Servers that have not run that migration yet fall back to
//  INSTRUCTOR_DEFAULT_PERMISSIONS — the same abilities instructors
//  had before this file grew, so a missing table degrades to the
//  old behaviour instead of locking everyone out.
// ============================================================

/**
 * Every permission the system knows about, grouped the way the
 * Manage Access modal renders them.
 *
 * Keys are stored in user_permissions_tbl.permission, so renaming
 * one is a migration — add a new key instead.
 */
const PERMISSION_CATALOG = [
    'attendance' => [
        'label' => 'Attendance',
        'icon'  => 'bi-journal-text',
        'items' => [
            'attendance.view' => [
                'label' => 'View attendance records',
                'note'  => 'Open the Attendance List and see their own records.',
                'icon'  => 'bi-list-check',
            ],
            'attendance.record' => [
                'label' => 'Record attendance',
                'note'  => 'Save scans and mark students present.',
                'icon'  => 'bi-check2-square',
            ],
            'attendance.import' => [
                'label' => 'Import attendance',
                'note'  => 'Upload attendance from a file.',
                'icon'  => 'bi-upload',
            ],
            'attendance.delete' => [
                'label' => 'Delete attendance records',
                'note'  => 'Remove their own attendance rows.',
                'icon'  => 'bi-trash',
            ],
            'attendance.export' => [
                'label' => 'Export reports',
                'note'  => 'Download attendance and absence PDFs.',
                'icon'  => 'bi-file-earmark-pdf',
            ],
            'links.manage' => [
                'label' => 'Manage attendance links',
                'note'  => 'Generate and deactivate scanning links.',
                'icon'  => 'bi-link-45deg',
            ],
        ],
    ],
    'students' => [
        'label' => 'Students',
        'icon'  => 'bi-people-fill',
        'items' => [
            'students.view' => [
                'label' => 'View the student list',
                'note'  => 'Open the Student List page.',
                'icon'  => 'bi-people',
            ],
            'students.manage' => [
                'label' => 'Add and edit students',
                'note'  => 'Create student records and change their details.',
                'icon'  => 'bi-person-plus',
            ],
            'students.import' => [
                'label' => 'Import students',
                'note'  => 'Bulk-import from CSV or Excel, and download the template.',
                'icon'  => 'bi-file-earmark-arrow-up',
            ],
            'students.delete' => [
                'label' => 'Delete students',
                'note'  => 'Remove student records. Wiping every student stays admin-only.',
                'icon'  => 'bi-person-dash',
            ],
            'students.promote' => [
                'label' => 'Promote sections',
                'note'  => 'Move a whole section up to the next year level.',
                'icon'  => 'bi-arrow-up-circle',
            ],
            'students.photos' => [
                'label' => 'View student photos',
                'note'  => 'Photo profiles of students in their sections.',
                'icon'  => 'bi-person-badge',
            ],
            'students.photos.delete' => [
                'label' => 'Delete student photos',
                'note'  => 'Remove a photo so the student can upload a new one.',
                'icon'  => 'bi-trash',
            ],
            'enrollment.manage' => [
                'label' => 'Manage subject enrollment',
                'note'  => 'Enroll and remove students from subjects.',
                'icon'  => 'bi-journal-bookmark',
            ],
        ],
    ],
    'academics' => [
        'label' => 'Academic Setup',
        'icon'  => 'bi-mortarboard',
        'items' => [
            'subjects.manage' => [
                'label' => 'Manage subjects',
                'note'  => 'Add, edit and remove subjects.',
                'icon'  => 'bi-journal-bookmark',
            ],
            'sections.assign' => [
                'label' => 'Assign sections',
                'note'  => 'Decide which sections an instructor handles.',
                'icon'  => 'bi-diagram-3',
            ],
            'instructors.assign' => [
                'label' => 'Assign subjects to instructors',
                'note'  => 'Decide which subjects an instructor teaches.',
                'icon'  => 'bi-person-badge',
            ],
        ],
    ],
    'system' => [
        'label' => 'System',
        'icon'  => 'bi-sliders',
        'items' => [
            'attendance.lock' => [
                'label' => 'Lock the attendance form',
                'note'  => 'Stop or resume attendance submissions system-wide.',
                'icon'  => 'bi-lock',
            ],
            'system.pagelock' => [
                'label' => 'Lock the QR pages',
                'note'  => 'Take the scanner, generator and tracker offline.',
                'icon'  => 'bi-shield-lock',
            ],
            'settings.manage' => [
                'label' => 'Change system settings',
                'note'  => 'System name, logo, report header and footer.',
                'icon'  => 'bi-gear',
            ],
            'backup.manage' => [
                'label' => 'Database backup',
                'note'  => 'Create, download and restore database backups.',
                'icon'  => 'bi-database',
            ],
            'db.monitor' => [
                'label' => 'Database monitor',
                'note'  => 'Table sizes and storage usage.',
                'icon'  => 'bi-activity',
            ],
        ],
    ],
    'qr' => [
        'label' => 'QR Tools',
        'icon'  => 'bi-qr-code',
        'items' => [
            'qr.generator' => [
                'label' => 'QR generator',
                'note'  => 'Create student QR codes.',
                'icon'  => 'bi-qr-code',
            ],
            'qr.scanner' => [
                'label' => 'QR scanner',
                'note'  => 'Scan QR codes to take attendance.',
                'icon'  => 'bi-qr-code-scan',
            ],
            'qr.tracker' => [
                'label' => 'Attendance tracker',
                'note'  => 'The live scan display board.',
                'icon'  => 'bi-search',
            ],
        ],
    ],
];

/**
 * What a brand-new instructor starts with, and the fallback when
 * user_permissions_tbl is missing. Deliberately equal to what every
 * instructor could do before per-user permissions existed.
 *
 * This is NOT "the whole catalog minus a few" — it is a snapshot of
 * the old behaviour, and it must stay that way. Everything added to
 * PERMISSION_CATALOG since (the Students, Academic Setup and System
 * groups) was previously admin territory, so it starts off and is
 * handed out one instructor at a time. Adding a key here would grant
 * it to every instructor at once on the next deploy.
 */
const INSTRUCTOR_DEFAULT_PERMISSIONS = [
    'attendance.view',
    'attendance.record',
    'attendance.import',
    'attendance.delete',
    'attendance.export',
    'links.manage',
    'students.photos',
    'enrollment.manage',
    'qr.generator',
    'qr.scanner',
    'qr.tracker',
];

function isAdmin(){
    return isset($_SESSION['role']) && $_SESSION['role']=='admin';
}

function isStaff(){
    return isset($_SESSION['role']) && $_SESSION['role']=='instructor';
}

/** Flat list of every valid permission key. */
function allPermissionKeys(): array {
    $keys = [];
    foreach (PERMISSION_CATALOG as $group) {
        foreach ($group['items'] as $key => $_meta) {
            $keys[] = $key;
        }
    }
    return $keys;
}

/**
 * The shared mysqli, without forcing a second connection.
 *
 * permissions.php is included BEFORE db_connect.php on several
 * pages, so the connection is looked up when can() is first called
 * rather than when this file loads. db_connect.php stashes it in
 * $GLOBALS['__bcc_conn'].
 *
 * If no connection has been made yet, db_connect.php is included
 * here rather than giving up: falling back to the defaults because a
 * guard happened to run one line too early would silently grant or
 * deny the wrong things. db_connect.php reuses the stashed handle,
 * so this cannot open a second one.
 */
function permissionsConn(): ?mysqli {
    foreach (['__bcc_conn', 'conn'] as $name) {
        if (isset($GLOBALS[$name]) && $GLOBALS[$name] instanceof mysqli) {
            return $GLOBALS[$name];
        }
    }

    include __DIR__ . '/db_connect.php';

    return isset($GLOBALS['__bcc_conn']) && $GLOBALS['__bcc_conn'] instanceof mysqli
        ? $GLOBALS['__bcc_conn']
        : null;
}

/**
 * The permissions granted to a user — read once per request.
 *
 * Not cached in the session on purpose: an admin revoking access
 * has to take effect on the instructor's very next page load, and
 * a session copy would keep working until they logged out again.
 * It is one indexed lookup on a two-column table.
 */
function userPermissions(?int $userId = null): array {
    static $cache = [];

    $userId ??= (int)($_SESSION['user_id'] ?? 0);
    if ($userId <= 0) {
        return [];
    }

    if (isset($cache[$userId])) {
        return $cache[$userId];
    }

    $conn = permissionsConn();
    if (!$conn) {
        // No database in this request (should not happen on a real
        // page) — assume the pre-permissions behaviour rather than
        // silently denying everything.
        return $cache[$userId] = INSTRUCTOR_DEFAULT_PERMISSIONS;
    }

    try {
        $stmt = $conn->prepare("SELECT permission FROM user_permissions_tbl WHERE user_id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $res = $stmt->get_result();

        $perms = [];
        while ($row = $res->fetch_assoc()) {
            $perms[] = $row['permission'];
        }
        $stmt->close();

        return $cache[$userId] = $perms;

    } catch (Throwable $e) {
        // The table is not there yet — see the file header.
        return $cache[$userId] = INSTRUCTOR_DEFAULT_PERMISSIONS;
    }
}

/**
 * Whether the signed-in user may do $permission.
 *
 * Admins always may. Everyone else needs the row.
 */
function can(string $permission): bool {
    if (!isset($_SESSION['user_id'])) {
        return false;
    }
    if (isAdmin()) {
        return true;
    }
    return in_array($permission, userPermissions(), true);
}

/** True when the user may do at least one of the given permissions. */
function canAny(array $permissions): bool {
    foreach ($permissions as $permission) {
        if (can($permission)) {
            return true;
        }
    }
    return false;
}

/**
 * Page guard: bounce to the dashboard when the permission is
 * missing, with a message the dashboard's alert box picks up.
 */
function requirePermission(string $permission, string $redirect = 'dashboard.php'): void {
    if (can($permission)) {
        return;
    }

    $_SESSION['alert'] = [
        'icon'     => 'error',
        'title'    => 'No Access',
        'text'     => 'You do not have permission to open that page. Please contact the administrator.',
        'position' => 'center',
    ];

    header("Location: " . $redirect);
    exit;
}

/**
 * Page guard for a page that hosts several separately-permissioned
 * things — settings.php is one page but three different rights.
 * Getting in needs any one of them; each section then checks its own,
 * so a permission is never granted but unreachable.
 */
function requireAnyPermission(array $permissions, string $redirect = 'dashboard.php'): void {
    if (canAny($permissions)) {
        return;
    }
    // Reuses requirePermission's alert and redirect for one message.
    requirePermission($permissions[0] ?? '__none__', $redirect);
}

/**
 * Guard for the pages that are also reachable without signing in —
 * the QR generator and the Tracker display board, which run on a
 * projector or a shared kiosk and never had an auth check.
 *
 * Anonymous visitors are left alone (that is the existing
 * behaviour); a signed-in instructor without the permission is
 * bounced, so unticking the box in Manage Access actually means
 * something for them.
 */
function requirePermissionIfSignedIn(string $permission, string $redirect = '../pages/dashboard.php'): void {
    if (empty($_SESSION['user_id'])) {
        return;
    }
    requirePermission($permission, $redirect);
}

/**
 * Endpoint guard: the JSON equivalent of requirePermission().
 *
 * $shape follows the two reply styles already in crud/ — some
 * endpoints answer {status,message}, others {success,message}.
 */
function requirePermissionJson(string $permission, string $shape = 'success'): void {
    if (can($permission)) {
        return;
    }

    if (!headers_sent()) {
        header('Content-Type: application/json');
    }

    echo json_encode($shape === 'status'
        ? ['status'  => 'error', 'message' => 'You do not have permission to do that.']
        : ['success' => false,   'message' => 'You do not have permission to do that.']);
    exit;
}

/**
 * Give a user the standard instructor set, but only if nothing has
 * been granted to them yet — an admin's own choices are never
 * overwritten by a later edit to the account.
 */
function seedDefaultPermissions(mysqli $conn, int $userId): bool {
    if ($userId <= 0) {
        return false;
    }

    try {
        $existing = $conn->prepare("SELECT 1 FROM user_permissions_tbl WHERE user_id = ? LIMIT 1");
        $existing->bind_param("i", $userId);
        $existing->execute();
        $already = $existing->get_result()->num_rows > 0;
        $existing->close();

        if ($already) {
            return true;
        }

        return setUserPermissions($conn, $userId, INSTRUCTOR_DEFAULT_PERMISSIONS);

    } catch (Throwable $e) {
        // Table not migrated yet — userPermissions() falls back to the
        // same defaults, so there is nothing to repair here.
        return false;
    }
}

/**
 * Replace a user's permissions with exactly $permissions.
 *
 * Unknown keys are dropped, so a tampered request cannot write
 * junk rows. Admins are skipped entirely — they pass every check
 * regardless, and storing rows for them would only suggest the
 * boxes mean something.
 */
function setUserPermissions(mysqli $conn, int $userId, array $permissions, ?int $grantedBy = null): bool {
    $valid = array_values(array_intersect(allPermissionKeys(), $permissions));

    $conn->begin_transaction();
    try {
        $del = $conn->prepare("DELETE FROM user_permissions_tbl WHERE user_id = ?");
        $del->bind_param("i", $userId);
        $del->execute();
        $del->close();

        if ($valid) {
            $ins = $conn->prepare("
                INSERT INTO user_permissions_tbl (user_id, permission, granted_by)
                VALUES (?, ?, ?)
            ");
            foreach ($valid as $permission) {
                $ins->bind_param("isi", $userId, $permission, $grantedBy);
                $ins->execute();
            }
            $ins->close();
        }

        $conn->commit();
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        return false;
    }
}
