<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/db_connect.php";

// Check if short code is provided
$attendance_data = null;
$is_valid = false;

if (isset($_GET['c'])) {
    $short_code = trim($_GET['c']);

    // Get link data from database
    $stmt = $conn->prepare("
        SELECT * FROM attendance_links_tbl 
        WHERE short_code = ? AND is_active = 1
    ");
    $stmt->bind_param("s", $short_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $attendance_data = [
            'subject_id' => $row['subject_id'],
            'subject_code' => $row['subject_code'],
            'subject_name' => $row['subject_name'],
            'section' => $row['section'],
            'instructor_id' => $row['instructor_id'],
            'instructor_name' => $row['instructor_name']
        ];
        $is_valid = true;
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
            <img style="width: 50px; height: 50px; border-radius: 50px;"
                src="https://cdn-icons-gif.flaticon.com/18995/18995020.gif" alt="">
            <h2 class="mb-0">Daily Attendance</h2>
            <p class="mb-0 mt-1 text-muted" style="font-size:.9rem;">
                <i class="bi bi-calendar3 me-1"></i><?php echo date('F d, Y'); ?>
            </p>

            <!-- Class Info -->
            <div class="mt-3 p-3 rounded-3" style="background: rgba(13,110,253,.1); border: 1px solid rgba(13,110,253,.25);">
                <h5 class="mb-2 fw-bold" style="color:#6ea8fe;">
                    <i class="bi bi-bookmark-fill me-1"></i>
                    <?php echo htmlspecialchars($attendance_data['subject_code']); ?> &mdash;
                    <?php echo htmlspecialchars($attendance_data['subject_name']); ?>
                </h5>
                <p class="mb-1" style="font-size:.88rem; color:#ced4da;">
                    <i class="bi bi-people-fill me-1" style="color:#20c997;"></i>
                    <strong>Section:</strong> <?php echo htmlspecialchars($attendance_data['section']); ?>
                </p>
                <p class="mb-0" style="font-size:.88rem; color:#ced4da;">
                    <i class="bi bi-person-badge me-1" style="color:#0dcaf0;"></i>
                    <strong>Instructor:</strong> <?php echo htmlspecialchars($attendance_data['instructor_name']); ?>
                </p>
            </div>

            <?php if ($is_locked): ?>
                <div class="mt-3 py-2 px-3 rounded-3 d-inline-flex align-items-center gap-2"
                    style="background: rgba(220,53,69,.15); border: 1px solid rgba(220,53,69,.3); color:#ea868f;">
                    <i class="bi bi-lock-fill"></i>
                    <span class="fw-semibold" style="font-size:.88rem; letter-spacing:.5px;">ATTENDANCE LOCKED</span>
                </div>
            <?php endif; ?>
        </div>
        <div class="card-body p-4">
            <div id="alertContainer"></div>
            <br>
            <form id="attendanceForm">
                <div class="input-container">
                    <div class="input-field-container">
                        <input type="text" id="studentNo" class="holo-input" placeholder="Enter your student number" required autocomplete="off" <?php echo $is_locked ? 'disabled' : ''; ?> />
                        <div class="input-border"></div>
                        <div class="holo-scan-line"></div>
                        <div class="input-glow"></div>
                        <div class="input-active-indicator" id="verifyingIndicator"></div>
                        <div class="input-label">Student Number</div>

                        <div class="input-data-visualization">
                            <?php for ($i = 1; $i <= 20; $i++): ?>
                                <div class="data-segment" style="--index: <?php echo $i; ?>;"></div>
                            <?php endfor; ?>
                        </div>

                        <div class="input-particles">
                            <div class="input-particle" style="--index: 1; top: 20%; left: 10%;"></div>
                            <div class="input-particle" style="--index: 2; top: 65%; left: 25%;"></div>
                            <div class="input-particle" style="--index: 3; top: 40%; left: 40%;"></div>
                            <div class="input-particle" style="--index: 4; top: 75%; left: 60%;"></div>
                            <div class="input-particle" style="--index: 5; top: 30%; left: 75%;"></div>
                            <div class="input-particle" style="--index: 6; top: 60%; left: 90%;"></div>
                        </div>

                        <div class="input-holo-overlay"></div>

                        <div class="interface-lines">
                            <div class="interface-line"></div>
                            <div class="interface-line"></div>
                            <div class="interface-line"></div>
                            <div class="interface-line"></div>
                        </div>

                        <div class="input-status">Ready for input</div>
                        <div class="power-indicator"></div>
                    </div>
                </div>

                <div id="studentInfo" class="student-info">
                    <h5 class="mb-3"><i class="bi bi-person-circle"></i> Student Information</h5>
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

                <button type="submit" class="btn btn-submit w-100 mt-4" id="submitBtn" disabled>
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

                const formData = new URLSearchParams();
                formData.append('student_no', verifiedStudentNo);
                formData.append('subject_id', attendanceData.subject_id);
                formData.append('subject_code', attendanceData.subject_code);
                formData.append('subject_name', attendanceData.subject_name);
                formData.append('section', attendanceData.section);
                formData.append('instructor_id', attendanceData.instructor_id);
                formData.append('instructor_name', attendanceData.instructor_name);

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
</body>

</html>