<?php
// Get current page filename
$current_page = basename($_SERVER['PHP_SELF']);
?>

<div class="sidebar" id="sidebar">
    <div class="logo d-flex flex-column align-items-center">
        <img src="../<?php echo $systemLogo; ?>" alt="BCC Logo" class="logo-img mb-2">
        <span class="logo-text"><?php echo $systemAcronym; ?></span>
    </div>

    <!-- MAIN -->
    <small class="sidebar-label">MAIN</small>
    <a href="../pages/dashboard.php" class="nav-link <?php echo ($current_page == 'dashboard.php') ? 'active' : ''; ?>" data-tip="Dashboard">
        <i class="bi bi-speedometer2"></i> <span>Dashboard</span>
    </a>

    <?php
    // Every section below is skipped entirely when the user holds none
    // of its permissions — an empty dropdown is worse than no dropdown.
    // Admins pass can() unconditionally, so their sidebar is unchanged.
    //
    // The Students block used to branch on the role: the full dropdown
    // for admins, a single photos link for instructors. Now it is the
    // same markup for both, driven by the two permissions — an
    // instructor granted students.view gets the dropdown too.
    ?>
    <?php if (canAny(['students.view', 'students.photos'])) { ?>
        <!-- STUDENTS -->
        <small class="sidebar-label">STUDENTS</small>
        <div class="nav-item dropdown">
            <a href="#" class="nav-link dropdown-toggle <?php echo (in_array($current_page, ['students.php', 'student_photo_profile.php'])) ? 'active' : ''; ?>" data-bs-toggle="collapse" data-bs-target="#studentMenu" data-tip="Students">
                <i class="bi bi-people-fill"></i> <span>Students</span>
            </a>
            <div class="collapse ps-3" id="studentMenu">
                <?php if (can('students.view')) { ?>
                    <a href="../pages/students.php" class="nav-link submenu-item <?php echo ($current_page == 'students.php') ? 'active' : ''; ?>">
                        <i class="bi bi-people-fill"></i> Student List
                    </a>
                <?php } ?>
                <?php if (can('students.photos')) { ?>
                    <a href="../pages/student_photo_profile.php" class="nav-link submenu-item <?php echo ($current_page == 'student_photo_profile.php') ? 'active' : ''; ?>">
                        <i class="bi bi-person-badge"></i> Student Photo Profile
                    </a>
                    <a href="../student/StudentPhotoProfile.php" target="_blank" class="nav-link submenu-item <?php echo ($current_page == 'StudentPhotoProfile.php') ? 'active' : ''; ?>">
                        <i class="bi bi-person-bounding-box"></i> Student Photo Upload
                    </a>
                <?php } ?>
            </div>
        </div>
    <?php } ?>
    <?php if (canAny(['attendance.view', 'links.manage'])) { ?>
        <!-- ATTENDANCE -->
        <small class="sidebar-label">ATTENDANCE</small>
        <div class="nav-item dropdown">
            <a href="#" class="nav-link dropdown-toggle <?php echo (in_array($current_page, ['attendance.php', 'generate_attendance_link.php'])) ? 'active' : ''; ?>" data-bs-toggle="collapse" data-bs-target="#attendanceMenu" data-tip="Attendance">
                <i class="bi bi-journal-text"></i> <span>Attendance</span>
            </a>
            <div class="collapse ps-3" id="attendanceMenu">
                <?php if (can('attendance.view')) { ?>
                    <a href="../pages/attendance.php" class="nav-link submenu-item <?php echo ($current_page == 'attendance.php') ? 'active' : ''; ?>">
                        <i class="bi bi-list-check"></i> Attendance List
                    </a>
                <?php } ?>
                <?php if (can('links.manage')) { ?>
                    <a href="../pages/generate_attendance_link.php" class="nav-link submenu-item <?php echo ($current_page == 'generate_attendance_link.php') ? 'active' : ''; ?>">
                        <i class="bi bi-link-45deg"></i> Attendance Link
                    </a>
                <?php } ?>
            </div>
        </div>
    <?php } ?>

    <?php if (canAny(['enrollment.manage', 'subjects.manage', 'sections.assign', 'instructors.assign'])) { ?>
    <!-- ACADEMICS -->
    <small class="sidebar-label">ACADEMICS</small>
    <div class="nav-item dropdown">
        <a href="#" class="nav-link dropdown-toggle <?php echo (in_array($current_page, ['manage_subject.php', 'manage_instructor_section.php', 'manage_instructor_subject.php'])) ? 'active' : ''; ?>" data-bs-toggle="collapse" data-bs-target="#acadMenu" data-tip="Academic Settings">
            <i class="bi bi-gear-fill"></i> <span>Academic Settings</span>
        </a>
        <div class="collapse ps-3" id="acadMenu">
            <?php if (can('enrollment.manage')) { ?>
                <a href="../pages/student_subjects.php" class="nav-link submenu-item <?php echo ($current_page == 'student_subjects.php') ? 'active' : ''; ?>">
                    <i class="bi bi-journal-bookmark"></i> Subject Enrollment
                </a>
            <?php } ?>
            <?php if (can('subjects.manage')) { ?>
                <a href="../pages/manage_subject.php" class="nav-link submenu-item <?php echo ($current_page == 'manage_subject.php') ? 'active' : ''; ?>">
                    <i class="bi bi-journal-bookmark"></i> Subjects
                </a>
            <?php } ?>
            <?php if (can('sections.assign')) { ?>
                <a href="../pages/manage_instructor_section.php" class="nav-link submenu-item <?php echo ($current_page == 'manage_instructor_section.php') ? 'active' : ''; ?>">
                    <i class="bi bi-diagram-3"></i> Sections
                </a>
            <?php } ?>
            <?php if (can('instructors.assign')) { ?>
                <a href="../pages/manage_instructor_subject.php" class="nav-link submenu-item <?php echo ($current_page == 'manage_instructor_subject.php') ? 'active' : ''; ?>">
                    <i class="bi bi-person-badge"></i> Instructors
                </a>
            <?php } ?>
        </div>
    </div>
    <?php } ?>

    <?php if (isAdmin()) { ?>
        <!-- ADMINISTRATION -->
        <small class="sidebar-label">ADMINISTRATION</small>
        <div class="nav-item dropdown">
            <a href="#" class="nav-link dropdown-toggle <?php echo ($current_page == 'manage_users.php') ? 'active' : ''; ?>" data-bs-toggle="collapse" data-bs-target="#userMenu" data-tip="Manage Users">
                <i class="bi bi-gear-fill"></i> <span>Manage Users</span>
            </a>
            <div class="collapse ps-3" id="userMenu">
                <a href="../pages/manage_users.php" class="nav-link submenu-item <?php echo ($current_page == 'manage_users.php') ? 'active' : ''; ?>">
                    <i class="bi bi-person"></i> Users
                </a>
            </div>
        </div>
    <?php } ?>

    <?php if (canAny(['qr.generator', 'qr.scanner', 'qr.tracker'])) { ?>
    <!-- QR TOOLS -->
    <small class="sidebar-label">QR TOOLS</small>
    <div class="nav-item dropdown">
        <a href="#" class="nav-link dropdown-toggle <?php echo (in_array($current_page, ['QRcode.php', 'view.php', 'qrscanner.php'])) ? 'active' : ''; ?>" data-bs-toggle="collapse" data-bs-target="#qrMenu" data-tip="QR Tools">
            <i class="bi bi-qr-code"></i><span>QR Tools</span>
        </a>
        <div class="collapse ps-3" id="qrMenu">
            <?php if (can('qr.generator')) { ?>
                <a href="../QRgenerator/QRcode.php" target="_blank" class="nav-link submenu-item <?php echo ($current_page == 'QRcode.php') ? 'active' : ''; ?>">
                    <i class="bi bi-qr-code"></i> QR Generator
                </a>
            <?php } ?>
            <?php if (can('qr.scanner')) { ?>
                <a href="../Qrscanner/qrscanner.php" target="_blank" class="nav-link submenu-item <?php echo ($current_page == 'qrscanner.php') ? 'active' : ''; ?>">
                    <i class="bi bi-qr-code-scan"></i> QR Scanner
                </a>
            <?php } ?>
            <?php if (can('qr.tracker')) { ?>
                <a href="../Tracker/view.php" target="_blank" class="nav-link submenu-item <?php echo ($current_page == 'view.php') ? 'active' : ''; ?>">
                    <i class="bi bi-search"></i> Attendance Tracker
                </a>
            <?php } ?>
        </div>
    </div>
    <?php } ?>

    <?php if (canAny(['backup.manage', 'db.monitor'])) { ?>
        <!-- SYSTEM -->
        <small class="sidebar-label">SYSTEM</small>
        <?php if (can('backup.manage')) { ?>
            <a href="../pages/backup.php" class="nav-link <?php echo ($current_page == 'backup.php') ? 'active' : ''; ?>" data-tip="Database Backup">
                <i class="bi bi-database"></i><span>Database Backup</span>
            </a>
        <?php } ?>
        <?php if (can('db.monitor')) { ?>
            <a href="../pages/db_monitor.php" class="nav-link <?php echo ($current_page == 'db_monitor.php') ? 'active' : ''; ?>" data-tip="Database Monitor">
                <i class="bi bi-activity"></i><span>Database Monitor</span>
            </a>
        <?php } ?>
    <?php } ?>

    <!-- ACCOUNT -->
    <small class="sidebar-label">ACCOUNT</small>
    <a href="#" class="nav-link" data-tip="Logout" onclick="confirmLogout()">
        <i class="bi bi-box-arrow-in-right"></i> <span>Logout</span>
    </a>

    <?php include __DIR__ . "/../components/footer.php"; ?>
</div>

<!-- The sidebar's styles now live in assets/css/sidebar.css (linked
     from includes/header.php) — no longer scattered across an inline
     <style> here and two blocks in main.css. -->

<script>
    document.addEventListener('DOMContentLoaded', function() {
        const dropdowns = [{
                toggle: '#studentMenu',
                pages: ['students.php', 'student_photo_profile.php']
            },
            {
                toggle: '#attendanceMenu',
                pages: ['attendance.php', 'generate_attendance_link.php']
            },
            {
                toggle: '#acadMenu',
                pages: ['manage_subject.php', 'manage_instructor_section.php', 'manage_instructor_subject.php']
            },
            {
                toggle: '#userMenu',
                pages: ['manage_users.php']
            },
            {
                toggle: '#qrMenu',
                pages: ['QRcode.php', 'view.php', 'qrscanner.php']
            }
        ];

        dropdowns.forEach(function(menu) {
            const collapseEl = document.getElementById(menu.toggle.substring(1));
            if (!collapseEl) return;

            const toggleEl = document.querySelector('[data-bs-target="' + menu.toggle + '"]');
            const hasActiveSubmenu = menu.pages.includes("<?php echo $current_page; ?>");
            const open = hasActiveSubmenu || localStorage.getItem(menu.toggle) === 'true';

            collapseEl.classList.toggle('show', open);

            // The initial state is written straight into the classList,
            // so Bootstrap never sees the opening and does not keep its
            // own `.collapsed` in step. Our own class drives the caret
            // direction instead.
            const syncCaret = function(isOpen) {
                if (!toggleEl) return;
                toggleEl.classList.toggle('expanded', isOpen);
                toggleEl.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
            };
            syncCaret(open);

            collapseEl.addEventListener('shown.bs.collapse', function() {
                localStorage.setItem(menu.toggle, 'true');
                syncCaret(true);
            });
            collapseEl.addEventListener('hidden.bs.collapse', function() {
                localStorage.setItem(menu.toggle, 'false');
                syncCaret(false);
            });
        });

        // ── Tooltip for the collapsed rail ───────────────────────
        // The `::after` tooltip in main.css is never visible: .sidebar
        // is `overflow-x: hidden`, so it gets clipped at the edge of
        // the 80px rail. A fixed element on <body> escapes that clip.
        // It is also where submenu items get their names — they were
        // bare icons when collapsed.
        const sidebar = document.getElementById('sidebar');
        if (!sidebar) return;

        const tip = document.createElement('div');
        tip.className = 'sidebar-tip';
        document.body.appendChild(tip);

        const hideTip = function() {
            tip.classList.remove('show');
        };

        sidebar.addEventListener('mouseover', function(e) {
            const link = e.target.closest('.nav-link');
            // On a phone the labels are shown in full (mobile.css), so
            // a tooltip there is only extra clutter.
            if (!link || !sidebar.classList.contains('collapsed') || window.innerWidth <= 992) {
                return hideTip();
            }

            // `data-tip` rather than `title`: the browser's native
            // tooltip would appear on top of ours. Submenu items have
            // no data-tip — their own text is used (they are
            // `font-size: 0` when collapsed, but the text is still in
            // the DOM).
            const label = (link.getAttribute('data-tip') || link.textContent || '').trim();
            if (!label) return hideTip();

            const rect = link.getBoundingClientRect();
            tip.textContent = label;
            tip.style.left = (rect.right + 12) + 'px';
            tip.style.top = (rect.top + rect.height / 2) + 'px';
            tip.classList.add('show');
        });

        sidebar.addEventListener('mouseleave', hideTip);
        sidebar.addEventListener('scroll', hideTip, { passive: true });
        window.addEventListener('resize', hideTip);
    });
</script>