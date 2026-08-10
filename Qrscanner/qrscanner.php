<?php
session_start();
include __DIR__ . "/../includes/auth.php";
include "../includes/db_connect.php";

// Fetch lock setting
$query = mysqli_query($conn, "SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked'");
$row = mysqli_fetch_assoc($query);
$locked = ($row['setting_value'] === 'true');

if ($locked) {
    include __DIR__ . "/../includes/lock.php";
    exit;
}

// Get instructor info from session
$instructor_name = $_SESSION['user_name'] ?? 'Admin';
$instructor_id   = $_SESSION['user_id']   ?? 0;
$role            = $_SESSION['role']       ?? 'instructor';

if ($role === 'admin') {
    // Admin sees ALL subjects
    $subjects_query = $conn->query("
        SELECT DISTINCT s.subject_code, s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        ORDER BY s.subject_name
    ");
    $subjects = $subjects_query ? $subjects_query->fetch_all(MYSQLI_ASSOC) : [];
} else {
    // Instructor sees only assigned subjects
    $subjects_query = $conn->prepare("
        SELECT s.subject_code, s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        WHERE si.instructor_id = ?
        ORDER BY s.subject_name
    ");
    $subjects_query->bind_param("i", $instructor_id);
    $subjects_query->execute();
    $result  = $subjects_query->get_result();
    $subjects = $result ? $result->fetch_all(MYSQLI_ASSOC) : [];
}

// Show message page if instructor has no subjects assigned
if (count($subjects) === 0 && $role !== 'admin') {
?>
    <!DOCTYPE html>
    <html>

    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <title>No Subjects Assigned</title>
        <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
        <link rel="stylesheet" href="css/style.css">
    </head>

    <body class="no-subjects-body">
        <div class="message-box">
            <h2>No Subjects Assigned</h2>
            <p>You don't have any subjects assigned to your account yet.</p>
            <p>Please contact the administrator to assign subjects.</p>
            <p><small>Your Instructor ID: <?= $instructor_id ?></small></p>
            <a href="../pages/dashboard.php" class="btn">Go to Dashboard</a>
        </div>
    </body>

    </html>
<?php
    exit;
}
?>
<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/headerQrScanner.php"; ?>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <!-- Nasa Qrscanner/css/style.css na ang mga estilo ng page na ito
         (tingnan ang "QR SCANNER PAGE" na seksyon doon). Wala talagang
         assets/css/qr-scanner.css — 404 lang ito kada page load. -->
</head>

<body>
    <!-- ============================================================
     DYNAMIC ISLAND — HTML SNIPPET
     ============================================================ -->

    <div id="di-outer">

        <!-- Avatar — floats above the island pill -->
        <div id="di-avatar-top" class="di-avatar-wrap">
            <div class="di-avatar-circle">
                <img id="di-photo" src="" alt="Student Photo">
                <div id="di-initials" class="di-avatar-initials"></div>
            </div>
            <div class="di-avatar-check">✓</div>
        </div>

        <!-- Island pill -->
        <div id="dynamic-island">

            <!-- Idle state — visible by default -->
            <div id="di-idle">
                <div class="di-dot"></div>
                <span>Ready to scan</span>
            </div>

            <!-- Expanded state — shows student info only, no avatar here -->
            <div id="di-content">
                <div id="di-name" class="di-student-name"></div>
                <div id="di-subject" class="di-student-subject"></div>
                <div id="di-time" class="di-scan-time"></div>
            </div>

            <!-- Auto-dismiss progress bar -->
            <div id="di-progress"></div>
        </div>

    </div>
    <header>
        <h2 class="header-title">
            <img src="../<?php echo $systemLogo; ?>"
                alt="System Logo"
                width="40" height="40"
                class="brand-logo">
            BCC SASQR Scanner
            <img src="https://cdn-icons-gif.flaticon.com/7994/7994392.gif"
                alt="QR Animation"
                width="40" height="40"
                style="border-radius: 50%; object-fit: cover;">
        </h2>
    </header>

    <main>
        <!-- ── Left Panel ──────────────────────────────────────── -->
        <div id="leftPanel">

            <div style="text-align: center;">
                <h2 style="display: inline-flex; align-items: center; gap: 10px;">
                    <img src="https://cdn-icons-gif.flaticon.com/15575/15575638.gif"
                        alt="QR Icon"
                        width="60" height="60"
                        style="border-radius: 50%; object-fit: cover;">
                </h2>
            </div>

            <!-- Subject Selection -->
            <div class="subject-selection">
                <div class="instructor-info">
                    <strong>
                        <?php if ($role === 'admin'): ?>
                            <span class="role-admin">Admin:</span>
                        <?php else: ?>
                            Instructor:
                        <?php endif; ?>
                    </strong>
                    <?= htmlspecialchars($instructor_name) ?>
                    <br>
                    <small>
                        ID: <?= $instructor_id ?> |
                        Subjects: <?= count($subjects) ?>
                        <?php if ($role === 'admin'): ?>
                            <span class="role-all-access"> | All Sections Accessible</span>
                        <?php endif; ?>
                    </small>
                </div>

                <label for="subjectSelect">Select Your Subject *</label>
                <select id="subjectSelect" required>
                    <option value="">-- Select Subject to Scan --</option>
                    <?php foreach ($subjects as $subject): ?>
                        <option value="<?= htmlspecialchars($subject['subject_code']) ?>"
                            data-name="<?= htmlspecialchars($subject['subject_name']) ?>">
                            <?= htmlspecialchars($subject['subject_name']) ?>
                            (<?= htmlspecialchars($subject['subject_code']) ?>)
                        </option>
                    <?php endforeach; ?>
                </select>

                <div id="scannerStatus" class="scanner-status">
                    Please select a subject first
                </div>
            </div>

            <!-- Scanner Frame -->
            <div id="scannerContainer">
                <video id="video" autoplay playsinline></video>
                <div class="overlay">
                    <div class="scanner-frame">
                        <div class="corner tl"></div>
                        <div class="corner tr"></div>
                        <div class="corner bl"></div>
                        <div class="corner br"></div>
                        <div class="scan-line"></div>
                    </div>
                </div>
            </div>

            <!-- Result Card -->
            <div id="result" class="card">

                <!-- Student info card — hidden by default, shows after scan -->
                <div id="studentCard" class="student-card">

                    <!-- Avatar -->
                    <div class="avatar-wrapper">
                        <div class="avatar-circle">
                            <img id="cardPhoto" class="avatar-photo" src="" alt="">
                            <div id="cardInitials" class="avatar-initials"></div>
                        </div>
                        <div class="avatar-check">✓</div>
                    </div>

                    <!-- Info -->
                    <div class="student-info">
                        <div id="cardName" class="student-name"></div>
                        <div id="cardMeta" class="student-meta"></div>
                        <div id="cardSubject" class="student-subject-badge"></div>
                    </div>

                    <!-- Timestamp -->
                    <div id="cardTime" class="scan-time"></div>
                </div>

                <!-- Status text -->
                <strong>Status :</strong> <span id="qrResult">Waiting...</span>
            </div>
        </div>

        <!-- ── Attendance List ─────────────────────────────────── -->
        <div id="attendance">
            <h3>
                <img class="attendance-gif"
                    src="https://cdn-icons-gif.flaticon.com/15575/15575693.gif"
                    alt="Attendance Icon">
                <br>Attendance List
            </h3>
            <table id="attendanceTable" class="display nowrap" style="width:100%">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Student Number</th>
                        <th>Name</th>
                        <th>Course</th>
                        <th>Section</th>
                        <th>Subject</th>
                        <th>Time</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
    </main>

    <?php include __DIR__ . "/../components/footer.php"; ?>

    <script src="https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.js"></script>
    <script>
        const loggedUserId = <?php echo json_encode($instructor_id); ?>;
        const instructorName = <?php echo json_encode($instructor_name); ?>;

        console.log('Instructor ID:', loggedUserId);
        console.log('Instructor Name:', instructorName);
        console.log('Subjects loaded:', <?= count($subjects) ?>);
    </script>
    <script src="../assets/js/tts.js"></script>
    <script src="js/scriptV3.js"></script>
</body>

</html>