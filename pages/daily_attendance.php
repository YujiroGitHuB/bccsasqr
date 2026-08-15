<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/db_connect.php";

// Check if short code is provided
$attendance_data = null;
$is_valid = false;

$invalid_reason = 'unknown';
$expires_in     = null;   // segundo hanggang mag-expire; null = walang expiry
$short_code     = '';

if (isset($_GET['c'])) {
    $short_code = trim($_GET['c']);

    // Get link data from database.
    //
    // Kinukuha ang hilera kahit patay o expired na, para masabi ng
    // pahina kung ALIN sa dalawa ang nangyari. Ang "wala ito" at ang
    // "tapos na ang oras" ay magkaibang balita para sa estudyanteng
    // nakatayo sa labas ng silid.
    //
    // Ang orasan ay sa database, hindi sa PHP: walang
    // date_default_timezone_set ang file na ito samantalang meron ang
    // crud/submit_attendance.php, kaya ang PHP na paghahambing ay
    // maaaring magsabing bukas pa ang link na tatanggihan naman ng
    // susunod na hakbang.
    $stmt = $conn->prepare("
        SELECT *,
               (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired,
               TIMESTAMPDIFF(SECOND, NOW(), expires_at)         AS expires_in
        FROM attendance_links_tbl
        WHERE short_code = ?
    ");
    $stmt->bind_param("s", $short_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();

        if ((int) $row['is_active'] !== 1) {
            $invalid_reason = 'inactive';
        } elseif ((int) $row['is_expired'] === 1) {
            $invalid_reason = 'expired';
        } else {
            $attendance_data = [
                'subject_id' => $row['subject_id'],
                'subject_code' => $row['subject_code'],
                'subject_name' => $row['subject_name'],
                'section' => $row['section'],
                'instructor_id' => $row['instructor_id'],
                'instructor_name' => $row['instructor_name']
            ];
            $expires_in = $row['expires_in'] === null ? null : (int) $row['expires_in'];
            $is_valid   = true;
        }
    }
}
// invalid link
if (!$is_valid) {
    include __DIR__ . '/../includes/invalid_link.php';
    exit();
}

// Check if form is locked
$result = $conn->query("SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");
$is_locked = 0;
if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    $is_locked = (int)$row['setting_value'];
}
?>

<!DOCTYPE html>
<html lang="en">

<head>

    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Online Attendance Forms</title>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <link rel="stylesheet" href="<?= asset('../assets/css/daily_attendance.css') ?>">
</head>

<body class="attendance-page">
    <?php include __DIR__ . "/../includes/attendance_lock.php" ?>
    <div class="attendance-card <?php echo $is_locked ? 'form-disabled' : ''; ?>">
        <div class="card-header">
            <img class="att-logo" src="../<?php echo $systemLogo; ?>"
                alt="<?php echo htmlspecialchars($systemName); ?>">
            <h1 class="att-title">Daily Attendance</h1>
            <p class="att-date">
                <i class="bi bi-calendar3"></i><?php echo date('F d, Y'); ?>
            </p>

            <!-- Class info. The subject code leads as a chip: it is what a
                 student checks first to know they opened the right link. -->
            <div class="att-class">
                <span class="att-class-code"><?php echo htmlspecialchars($attendance_data['subject_code']); ?></span>
                <h2 class="att-class-name"><?php echo htmlspecialchars($attendance_data['subject_name']); ?></h2>
                <div class="att-meta">
                    <p class="att-meta-row">
                        <i class="bi bi-people-fill"></i>
                        <span class="att-meta-label">Section</span>
                        <?php echo htmlspecialchars($attendance_data['section']); ?>
                    </p>
                    <p class="att-meta-row">
                        <i class="bi bi-person-badge"></i>
                        <span class="att-meta-label">Instructor</span>
                        <?php echo htmlspecialchars($attendance_data['instructor_name']); ?>
                    </p>
                </div>
            </div>

            <?php if ($is_locked): ?>
                <div class="att-locked">
                    <i class="bi bi-lock-fill"></i>
                    <span>ATTENDANCE LOCKED</span>
                </div>
            <?php endif; ?>

            <?php if ($expires_in !== null): ?>
                <!-- Ang bilang pababa ay pakikisama, hindi ang bantay: ang
                     tunay na tseke ay nasa crud/submit_attendance.php, na
                     tumitingin sa short_code sa bawat pagsusumite. Ito ay
                     nariyan para hindi mabigla ang estudyante — nakikita
                     niya ang natitirang oras bago pa siya magsimula. -->
                <div class="att-expiry" id="attExpiry" data-seconds="<?php echo $expires_in; ?>">
                    <i class="bi bi-hourglass-split"></i>
                    <span id="attExpiryText">Closes in <span id="attExpiryClock">—</span></span>
                </div>
            <?php endif; ?>
        </div>
        <div class="card-body">
            <div id="alertContainer"></div>
            <form id="attendanceForm">
                <div class="att-field">
                    <label class="att-label" for="studentNo">Student Number</label>
                    <div class="att-input-wrap">
                        <!-- The icon and the indicator follow the input in the
                             DOM so the focus styles can reach them with `~`. -->
                        <input type="text" id="studentNo" class="att-input" placeholder="e.g. 019-464" required
                            autocomplete="off" inputmode="text" <?php echo $is_locked ? 'disabled' : ''; ?> />
                        <i class="bi bi-person-vcard att-input-icon"></i>
                        <span class="att-status" id="verifyingIndicator"></span>
                    </div>
                    <p class="att-hint">
                        <i class="bi bi-info-circle"></i>
                        Your details are checked automatically as you type.
                    </p>
                </div>

                <div id="studentInfo" class="student-info">
                    <h5><i class="bi bi-patch-check-fill"></i> Student Verified</h5>
                    <div class="info-row">
                        <span class="info-label">Student Number:</span>
                        <span class="info-value" id="displayStudentNo"></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Full Name:</span>
                        <span class="info-value" id="displayFullname"></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Course:</span>
                        <span class="info-value" id="displayCourse"></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Section:</span>
                        <span class="info-value" id="displaySection"></span>
                    </div>
                </div>

                <button type="submit" class="btn-submit" id="submitBtn" disabled>
                    <span id="submitText"><i class="bi bi-check-circle"></i> Submit Attendance</span>
                    <span id="loadingSpinner">
                        <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
                        Processing...
                    </span>
                </button>
            </form>
        </div>
        <!-- footer -->
        <?php include __DIR__ . "/../components/footer.php"; ?>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="<?= asset('../assets/js/tts.js') ?>"></script>
    <script src="<?= asset('../assets/js/detection.js') ?>"></script>
    <script>
        const isFormLocked = <?php echo $is_locked ? 'true' : 'false'; ?>;
        const attendanceData = <?php echo json_encode($attendance_data); ?>;
        const shortCode = <?php echo json_encode($short_code); ?>;

        // ── Bilang pababa hanggang sa pagsara ────────────────────────
        // Isinasara ang form sa zero para malinaw ang nangyari, pero ang
        // server pa rin ang nagpapasya: kahit i-edit ang orasan ng
        // telepono o pakialaman ang JavaScript, ang short_code ang
        // sinusuri sa pagsusumite.
        (function () {
            const box = document.getElementById('attExpiry');
            if (!box) return;

            let left = parseInt(box.dataset.seconds, 10);
            const clock = document.getElementById('attExpiryClock');
            const text = document.getElementById('attExpiryText');

            function paint() {
                if (left <= 0) {
                    box.classList.add('is-over');
                    text.textContent = 'This attendance link has closed.';
                    const btn = document.getElementById('submitBtn');
                    const no = document.getElementById('studentNo');
                    if (btn) btn.disabled = true;
                    if (no) no.disabled = true;
                    clearInterval(tick);
                    return;
                }

                const h = Math.floor(left / 3600);
                const m = Math.floor((left % 3600) / 60);
                const s = left % 60;

                // Naka-pad para hindi tumatalon ang lapad kada segundo.
                const pad = n => String(n).padStart(2, '0');

                clock.textContent = h > 0
                    ? h + 'h ' + pad(m) + 'm ' + pad(s) + 's'
                    : (m > 0 ? m + 'm ' + pad(s) + 's' : s + 's');

                // Ang huling limang minuto ay iba ang kulay — sapat pang
                // panahon para magmadali, hindi pa huli.
                box.classList.toggle('is-soon', left <= 300);
                left--;
            }

            const tick = setInterval(paint, 1000);
            paint();
        })();

        let verifiedStudentNo = null;
        let typingTimer;
        const typingDelay = 800;

        function verifyStudent(studentNo) {
            if (!studentNo || isFormLocked) return;

            const indicator = document.getElementById('verifyingIndicator');
            indicator.classList.add('verifying');

            const formData = new URLSearchParams();
            formData.append('student_no', studentNo);
            formData.append('subject_code', attendanceData.subject_code);
            formData.append('required_section', attendanceData.section);
            formData.append('instructor_id', attendanceData.instructor_id); // ← ADDED

            fetch('../crud/verify_student.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded'
                    },
                    body: formData
                })
                .then(response => response.json())
                .then(data => {
                    indicator.classList.remove('verifying');
                    if (data.success) {
                        document.getElementById('displayStudentNo').textContent = data.student.student_no;
                        document.getElementById('displayFullname').textContent = data.student.fullname;
                        document.getElementById('displayCourse').textContent = data.student.course;
                        document.getElementById('displaySection').textContent = data.student.section;

                        document.getElementById('studentInfo').style.display = 'block';
                        document.getElementById('submitBtn').disabled = false;
                        verifiedStudentNo = data.student.student_no;

                        showAlert('Student verified successfully!', 'success');
                        TTSManager.speak('Student verified successfully!');
                    } else {
                        document.getElementById('studentInfo').style.display = 'none';
                        document.getElementById('submitBtn').disabled = true;
                        verifiedStudentNo = null;
                        showAlert(data.message, 'danger');
                        TTSManager.speak(data.message);
                    }
                })
                .catch(error => {
                    indicator.classList.remove('verifying');
                    showAlert('An error occurred. Please try again.', 'danger');
                    TTSManager.speak('An error occurred. Please try again.');
                    console.error('Error:', error);
                });
        }

        if (!isFormLocked) {
            document.getElementById('studentNo').addEventListener('input', function() {
                clearTimeout(typingTimer);
                document.getElementById('studentInfo').style.display = 'none';
                document.getElementById('submitBtn').disabled = true;
                verifiedStudentNo = null;

                const studentNo = this.value.trim();
                if (studentNo) {
                    typingTimer = setTimeout(() => verifyStudent(studentNo), typingDelay);
                }
            });

            document.getElementById('studentNo').addEventListener('blur', function() {
                clearTimeout(typingTimer);
                const studentNo = this.value.trim();
                if (studentNo && !verifiedStudentNo) {
                    verifyStudent(studentNo);
                }
            });

            document.getElementById('studentNo').addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    clearTimeout(typingTimer);
                    const studentNo = this.value.trim();
                    if (studentNo) verifyStudent(studentNo);
                }
            });

            document.getElementById('attendanceForm').addEventListener('submit', function(e) {
                e.preventDefault();

                if (!verifiedStudentNo) {
                    showAlert('Please verify your student number first', 'warning');
                    TTSManager.speak('Please verify your student number first');
                    return;
                }

                document.getElementById('submitBtn').disabled = true;
                document.getElementById('submitText').style.display = 'none';
                document.getElementById('loadingSpinner').style.display = 'inline';

                // Ang short_code lamang ang ipinapadala para sa klase.
                // Dati ay galing sa mga hidden field ang subject, section
                // at instructor — na nangangahulugang kahit sino ay
                // makakapag-POST ng kahit anong halaga nang hindi
                // hawak ang link. Sa server na kinukuha ang mga ito
                // ngayon, mula mismo sa hilera ng link.
                const formData = new URLSearchParams();
                formData.append('student_no', verifiedStudentNo);
                formData.append('short_code', shortCode);

                fetch('../crud/submit_attendance.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/x-www-form-urlencoded'
                        },
                        body: formData
                    })
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            showAlert(data.message, 'success');
                            TTSManager.speak(data.message);

                            setTimeout(() => {
                                document.getElementById('attendanceForm').reset();
                                document.getElementById('studentInfo').style.display = 'none';
                                document.getElementById('submitBtn').disabled = true;
                                verifiedStudentNo = null;
                                document.getElementById('alertContainer').innerHTML = '';
                            }, 2000);
                        } else {
                            showAlert(data.message, 'warning');
                            TTSManager.speak(data.message);
                        }
                    })
                    .catch(error => {
                        showAlert('An error occurred. Please try again.', 'danger');
                        TTSManager.speak('An error occurred. Please try again.');
                        console.error('Error:', error);
                    })
                    .finally(() => {
                        document.getElementById('submitBtn').disabled = false;
                        document.getElementById('submitText').style.display = 'inline';
                        document.getElementById('loadingSpinner').style.display = 'none';
                    });
            });
        }

        function showAlert(message, type) {
            const alertContainer = document.getElementById('alertContainer');
            const alert = document.createElement('div');
            alert.className = `alert alert-${type} alert-dismissible fade show`;
            alert.innerHTML = `
                ${message}
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            `;
            alertContainer.innerHTML = '';
            alertContainer.appendChild(alert);

            setTimeout(() => {
                if (alert.parentNode) alert.remove();
            }, 5000);
        }
    </script>
<?php include __DIR__ . "/../includes/theme_toggle.php"; ?>
</body>

</html>