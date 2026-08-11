<?php require_once __DIR__ . '/../includes/asset.php';

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
        <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
        <link rel="stylesheet" href="<?= asset('css/style.css') ?>">
    </head>

    <body class="no-subjects-body">
        <div class="message-box">
            <div class="message-icon"><i class="bi bi-journal-x" aria-hidden="true"></i></div>
            <h2>No Subjects Assigned</h2>
            <p>You don't have any subjects assigned to your account yet. Ask an administrator to assign one before you can scan.</p>
            <p class="message-id">Instructor ID <?= (int)$instructor_id ?></p>
            <a href="../pages/dashboard.php" class="btn">
                <i class="bi bi-grid-1x2-fill" aria-hidden="true"></i> Go to Dashboard
            </a>
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
    <!-- Ang pamagat ay galing na sa Settings ($systemAcronym) sa halip
         na nakasulat na "BCC SASQR" — isang lugar na lang ang pinagmumulan
         ng pangalan ng sistema.

         Tinanggal ang dalawang GIF mula sa flaticon CDN (isa rito, isa sa
         #leftPanel): dekorasyon lamang sila, panlabas na request bawat
         page load, at wala sa bokabularyo ng natitirang bahagi ng app. -->
    <header>
        <div class="scan-head">
            <img src="../<?php echo htmlspecialchars($systemLogo); ?>"
                alt=""
                width="40" height="40"
                class="brand-logo">

            <div class="scan-head-text">
                <h2 class="header-title"><?= htmlspecialchars($systemAcronym) ?> Scanner</h2>
                <p>QR attendance capture</p>
            </div>

            <!-- Wala talagang paraang bumalik sa app mula rito noon
                 maliban sa back button ng browser. -->
            <a class="scan-head-back" href="../pages/dashboard.php">
                <i class="bi bi-grid-1x2-fill" aria-hidden="true"></i>
                <span>Dashboard</span>
            </a>
        </div>
    </header>

    <main>
        <!-- ── Left Panel ──────────────────────────────────────── -->
        <div id="leftPanel">

            <!-- Subject Selection -->
            <div class="subject-selection">

                <!-- Compact na kapalit ng buong subject picker habang
                     nag-i-scan sa telepono. Nakatago sa desktop. -->
                <div class="scan-chip" id="scanChip">
                    <i class="bi bi-camera-video-fill"></i>
                    <span class="scan-chip-subject" id="scanChipSubject"></span>
                    <button type="button" class="scan-chip-change" id="scanChipChange">
                        Change
                    </button>
                </div>

                <!-- Sinong nakatayo sa likod ng camera. Dating apat na
                     halaga sa dalawang linyang pinaghihiwalay ng "|" —
                     hanay na ngayon: mukha sa kaliwa, pangalan at chip
                     ng papel sa kanan. -->
                <div class="instructor-info">
                    <div class="instructor-avatar">
                        <i class="bi bi-person-fill" aria-hidden="true"></i>
                    </div>
                    <div class="instructor-meta">
                        <span class="instructor-name"><?= htmlspecialchars($instructor_name) ?></span>
                        <span class="instructor-chips">
                            <?php if ($role === 'admin'): ?>
                                <span class="scan-chip-tag role-admin">Admin</span>
                                <span class="scan-chip-tag role-all-access">All sections</span>
                            <?php else: ?>
                                <span class="scan-chip-tag">Instructor</span>
                            <?php endif; ?>
                            <span class="scan-chip-tag is-quiet">
                                <?= count($subjects) ?> subject<?= count($subjects) === 1 ? '' : 's' ?>
                            </span>
                            <span class="scan-chip-tag is-quiet">ID <?= (int)$instructor_id ?></span>
                        </span>
                    </div>
                </div>

                <label for="subjectSelect">Select Your Subject <span class="req">*</span></label>
                <div class="scan-field">
                    <i class="bi bi-journal-bookmark-fill" aria-hidden="true"></i>
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
                </div>

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
                <strong>Status</strong> <span id="qrResult">Waiting...</span>
            </div>
        </div>

        <!-- ── Attendance List ─────────────────────────────────── -->
        <div id="attendance">
            <h3>
                <i class="bi bi-card-checklist" aria-hidden="true"></i>
                Attendance List
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
    <script src="<?= asset('../assets/js/tts.js') ?>"></script>
    <script src="<?= asset('js/scriptV3.js') ?>"></script>
</body>

</html>