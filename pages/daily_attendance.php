<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";

// ── Ang cookie ng device, itinatanim bago ang anumang output ──
//
// Dito, at hindi sa crud/submit_attendance.php lamang: ang setcookie
// ay header, at ang header ay dapat mauna sa unang byte ng HTML.
// Kapag sa pagsusumite pa lamang ito unang naitanim, walang cookie
// ang unang pagsusumite ng bawat browser — at ang unang pagsusumite
// ang mismong hinuhuli ng device binding.
//
// Ang tumatawag na ito ang gumagawa rin ng integrity_secret sa
// unang pagtakbo, kaya handa na ang lahat bago pa dumating ang
// unang estudyante.
$device_id = integrity_device_id($conn);

// Check if short code is provided
$attendance_data = null;
$is_valid = false;

$invalid_reason  = 'unknown';
$expires_in      = null;   // segundo hanggang mag-expire; null = walang expiry
$short_code      = '';
$needs_room_code = false;  // binuksan ba ang code sa harapan para sa link na ito

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
            $expires_in    = $row['expires_in'] === null ? null : (int) $row['expires_in'];
            $needs_room_code = (int) ($row['require_room_code'] ?? 0) === 1;
            $is_valid      = true;
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
<!-- In-app browser notice (assets/js/detection.js): ang anyo nito ay
     nasa CSS na, hindi na sa loob ng JavaScript. -->
<link rel="stylesheet" href="<?= asset('../assets/css/detection.css') ?>">
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

                    <!-- Ang mukha muna bago ang mga datos: ito ang tinitingnan
                         ng estudyante para malamang siya nga ang na-verify, at
                         hindi ang kaklaseng iisang digit lang ang pagkakaiba ng
                         numero. Kapag walang larawan, inisyal ang lumalabas —
                         may kasamang sabing hindi iyon larawan, dahil sa unang
                         sulyap ay mapagkakamalan itong mukha (ganito rin ang
                         pananalita ng scanner). -->
                    <div class="att-profile">
                        <div class="att-avatar" id="studentAvatar">
                            <img class="att-avatar-img" id="displayPhoto" alt="" hidden>
                            <span class="att-avatar-initials" id="displayInitials"></span>
                            <i class="bi bi-check-circle-fill att-avatar-check"></i>
                        </div>
                        <div class="att-profile-id">
                            <p class="att-profile-name" id="displayFullname"></p>
                            <p class="att-profile-no" id="displayStudentNo"></p>
                            <p class="att-profile-note" id="displayPhotoNote" hidden>
                                <i class="bi bi-exclamation-triangle-fill"></i>
                                No photo on file
                            </p>
                        </div>
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

                <?php if ($needs_room_code): ?>
                    <!-- Ang tanging bagay sa pahinang ito na hindi kayang
                         dalhin palabas ng silid. Ang link ay naipapasa sa
                         group chat; ang anim na digit na ito ay may
                         tatlumpung segundong buhay, kaya sa oras na
                         maipadala mo ito, patay na.

                         inputmode="numeric" — pambilang na keypad sa
                         telepono. Ang pattern at maxlength ay pakikisama
                         lamang; sa crud/submit_attendance.php ang tseke. -->
                    <div class="att-field att-room">
                        <label class="att-label" for="roomCode">Code on the board</label>
                        <div class="att-input-wrap">
                            <input type="text" id="roomCode" class="att-input att-room-input"
                                placeholder="000000" required autocomplete="off"
                                inputmode="numeric" pattern="[0-9]*" maxlength="6"
                                <?php echo $is_locked ? 'disabled' : ''; ?> />
                        </div>
                        <p class="att-hint">
                            <i class="bi bi-display"></i>
                            Type the 6 digits your instructor is showing. It changes every 30 seconds.
                        </p>
                    </div>
                <?php endif; ?>

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

    <!-- ── Selfie spot check ──────────────────────────────────
         Nasa labas ng .attendance-card: position:fixed ito, at ang
         card ay may overflow:hidden na puputol dito.

         Nakatago hanggang sabihin ng server. Hindi nagpapasya ang
         JavaScript kung sino ang tatanungin — kung ganoon, ang
         kailangan lamang gawin ay patayin ang JavaScript. -->
    <div class="att-selfie" id="selfieOverlay" hidden>
        <h2 class="att-selfie-title"><i class="bi bi-camera-fill"></i> Quick photo check</h2>
        <p class="att-selfie-note" id="selfieNote">
            You were picked at random. Take a photo of yourself to finish submitting.
        </p>

        <div class="att-selfie-stage">
            <video id="selfieVideo" playsinline muted autoplay></video>
            <img id="selfieShot" alt="" hidden>
        </div>

        <div class="att-selfie-actions">
            <button type="button" class="att-selfie-btn" id="selfieCapture">
                <i class="bi bi-camera"></i> Take photo
            </button>
            <button type="button" class="att-selfie-btn ghost" id="selfieRetake" hidden>
                <i class="bi bi-arrow-counterclockwise"></i> Retake
            </button>
            <button type="button" class="att-selfie-btn" id="selfieSend" hidden>
                <i class="bi bi-send"></i> Use this photo
            </button>
            <button type="button" class="att-selfie-btn ghost" id="selfieCancel">
                <i class="bi bi-x-lg"></i> Cancel
            </button>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="<?= asset('../assets/js/tts.js') ?>"></script>
    <script src="<?= asset('../assets/js/detection.js') ?>"></script>
    <script>
        const isFormLocked = <?php echo $is_locked ? 'true' : 'false'; ?>;
        const attendanceData = <?php echo json_encode($attendance_data); ?>;
        const shortCode = <?php echo json_encode($short_code); ?>;
        const needsRoomCode = <?php echo $needs_room_code ? 'true' : 'false'; ?>;

        // ── Fingerprint ──────────────────────────────────────────────
        // Hindi ito ang device binding — ang cookie iyon, at ang server
        // ang may hawak. Ito ay pangalawang senyas lamang para sa
        // pages/attendance_integrity.php: kapag binura ang cookie,
        // nananatiling pareho ang hash na ito, at ang anim na
        // "bagong device" na iisa ang fingerprint sa loob ng isang
        // minuto ay may sinasabi.
        //
        // Sinasadyang mahina: hindi ito humaharang kahit kailan, dahil
        // ang dalawang bagong teleponong magkapareho ang modelo ay
        // magkapareho rin ang bawat sangkap dito. Ang paghaharang sa
        // isang hulang ganito ay pagtanggi sa taong walang ginawa.
        function deviceFingerprint() {
            const bits = [
                navigator.userAgent,
                navigator.language,
                (navigator.languages || []).join(','),
                screen.width + 'x' + screen.height,
                screen.colorDepth,
                new Date().getTimezoneOffset(),
                navigator.hardwareConcurrency || '',
                navigator.maxTouchPoints || ''
            ].join('|');

            // FNV-1a — sapat para sa paghahambing, at walang
            // kailangang i-load na library. Hindi ito lihim: ang
            // gustong magpalit nito ay makakapagpalit.
            let h = 0x811c9dc5;
            for (let i = 0; i < bits.length; i++) {
                h ^= bits.charCodeAt(i);
                h = Math.imul(h, 0x01000193) >>> 0;
            }

            return ('0000000' + h.toString(16)).slice(-8);
        }

        const deviceFp = deviceFingerprint();

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

        // ── Larawan ng na-verify na estudyante ───────────────────────
        // Inisyal ang laging nauuna, at ang larawan ay pinapalitan lamang
        // ito kapag talagang na-load na. Kaya walang lumang mukhang
        // naiiwan sa susunod na paghahanap, at walang sirang icon kapag
        // nawala ang file sa uploads/ — ang mali sa mukha ang pinakamasama
        // sa pahinang ito.
        function initialsOf(fullname) {
            const parts = String(fullname || '').trim().split(/\s+/).filter(Boolean);
            if (!parts.length) return '?';
            const first = parts[0][0];
            const last  = parts.length > 1 ? parts[parts.length - 1][0] : '';
            return (first + last).toUpperCase();
        }

        function showProfilePhoto(student) {
            const img      = document.getElementById('displayPhoto');
            const initials = document.getElementById('displayInitials');
            const note     = document.getElementById('displayPhotoNote');

            initials.textContent = initialsOf(student.fullname);
            initials.hidden = false;
            img.hidden = true;
            img.removeAttribute('src');
            note.hidden = !!student.photo_url;

            if (!student.photo_url) return;

            const probe = new Image();
            probe.onload = () => {
                img.src = student.photo_url;
                img.alt = 'Photo of ' + (student.fullname || 'student');
                img.hidden = false;
                initials.hidden = true;
            };
            probe.onerror = () => {
                // Nakatala ang larawan pero hindi ito mabuksan. Inisyal pa
                // rin ang nakikita, at sinasabi nitong wala — mas mabuti
                // ang kulang kaysa sa hindi mo alam kung ano ang tinitingnan.
                note.hidden = false;
            };
            probe.src = student.photo_url;
        }

        function verifyStudent(studentNo) {
            if (!studentNo || isFormLocked) return;

            const indicator = document.getElementById('verifyingIndicator');
            indicator.classList.add('verifying');

            // Ang short_code lamang, gaya ng sa pagsusumite. Dati ay
            // ipinapadala rito ang subject_code, section at
            // instructor_id — at dahil doon, ang endpoint ay
            // sumasagot sa kahit sinong nakakaalam ng tatlong halagang
            // iyon, nang hindi hawak ang link. Isang loop mula 025-001
            // pataas at nasa'yo na ang pangalan at larawan ng bawat
            // estudyante. Sa server na binabasa ang klase ngayon, mula
            // mismo sa hilera ng link.
            const formData = new URLSearchParams();
            formData.append('student_no', studentNo);
            formData.append('short_code', shortCode);

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
                        showProfilePhoto(data.student);

                        document.getElementById('studentInfo').style.display = 'block';
                        document.getElementById('submitBtn').disabled = false;
                        verifiedStudentNo = data.student.student_no;

                        if (data.photo_missing) {
                            // Hindi pa kailangan ang larawan — puwede siyang
                            // magpatuloy. Paalala lamang ito habang maluwag
                            // pa ang tuntunin.
                            const msg = 'Student verified. You have no photo on file yet — please upload one.';
                            showAlert(msg, 'warning', data.upload_url, 'Upload my photo');
                            TTSManager.speak(msg);
                        } else {
                            showAlert('Student verified successfully!', 'success');
                            TTSManager.speak('Student verified successfully!');
                        }
                    } else {
                        document.getElementById('studentInfo').style.display = 'none';
                        document.getElementById('submitBtn').disabled = true;
                        verifiedStudentNo = null;
                        showAlert(data.message, 'danger', data.upload_url, 'Upload my photo');
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

                if (needsRoomCode) {
                    const typed = (document.getElementById('roomCode').value || '').replace(/\D/g, '');
                    if (typed.length !== 6) {
                        showAlert('Enter the 6-digit code your instructor is showing.', 'warning');
                        TTSManager.speak('Enter the six digit code your instructor is showing.');
                        return;
                    }
                }

                sendAttendance(null);
            });
        }

        // ── Ang pagsusumite, hiwalay sa pindot ───────────────────────
        // Dalawa ang tumatawag nito: ang Submit, at ang selfie kapag
        // hiniling ito ng server. Kung nasa loob ito ng submit handler,
        // ang pangalawang pagpapadala ay magiging kopya — at ang
        // kopyang iyon ang unang makakalimot ng bagong field.
        function sendAttendance(selfieDataUrl) {
            const btn     = document.getElementById('submitBtn');
            const text    = document.getElementById('submitText');
            const spinner = document.getElementById('loadingSpinner');

            btn.disabled = true;
            text.style.display = 'none';
            spinner.style.display = 'inline';

            // Ang short_code lamang ang ipinapadala para sa klase.
            // Dati ay galing sa mga hidden field ang subject, section
            // at instructor — na nangangahulugang kahit sino ay
            // makakapag-POST ng kahit anong halaga nang hindi
            // hawak ang link. Sa server na kinukuha ang mga ito
            // ngayon, mula mismo sa hilera ng link.
            const formData = new URLSearchParams();
            formData.append('student_no', verifiedStudentNo);
            formData.append('short_code', shortCode);
            formData.append('fp', deviceFp);

            if (needsRoomCode) {
                formData.append('room_code', (document.getElementById('roomCode').value || '').replace(/\D/g, ''));
            }

            if (selfieDataUrl) {
                formData.append('selfie', selfieDataUrl);
            }

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
                        closeSelfie();
                        showAlert(data.message, 'success');
                        TTSManager.speak(data.message);

                        setTimeout(() => {
                            document.getElementById('attendanceForm').reset();
                            document.getElementById('studentInfo').style.display = 'none';
                            document.getElementById('submitBtn').disabled = true;
                            verifiedStudentNo = null;
                            document.getElementById('alertContainer').innerHTML = '';
                        }, 2000);
                        return;
                    }

                    // Hiniling ng server ang mukha. Hindi ito
                    // pagtanggi — hakbang lamang na kulang pa, kaya
                    // bumubukas ang camera imbes na maglabas ng
                    // pulang mensaheng walang sinasabing gawin.
                    if (data.code === 'selfie_required') {
                        openSelfie(data.message);
                        return;
                    }

                    // Ang photo_required ay may kasamang daan palabas:
                    // walang saysay ang sabihing kulang ang larawan
                    // kung hindi mo naman sasabihin kung saan ito
                    // ita-upload.
                    closeSelfie();
                    showAlert(data.message, 'warning', data.upload_url, 'Upload my photo');
                    TTSManager.speak(data.message);

                    // Ang maling code ay malamang na typo o lumipas na
                    // ang oras. Binubura ito at ibinabalik ang focus,
                    // dahil ang susunod na gagawin ay tipahin itong
                    // muli mula sa screen sa harapan.
                    if (data.code === 'room_code_bad' || data.code === 'room_code_required') {
                        const field = document.getElementById('roomCode');
                        if (field) {
                            field.value = '';
                            field.focus();
                        }
                    }
                })
                .catch(error => {
                    showAlert('An error occurred. Please try again.', 'danger');
                    TTSManager.speak('An error occurred. Please try again.');
                    console.error('Error:', error);
                })
                .finally(() => {
                    btn.disabled = false;
                    text.style.display = 'inline';
                    spinner.style.display = 'none';
                });
        }

        // ── Selfie spot check ────────────────────────────────────────
        //
        // Hindi kailanman nagpapasya ang JavaScript kung sino ang
        // tatanungin — ang server, at deterministiko ito kada araw.
        // Kaya walang mapapala sa pag-refresh: pareho pa rin ang
        // itatanong. Ang tanging ginagawa rito ay ang camera.
        let selfieStream = null;

        function openSelfie(note) {
            const box = document.getElementById('selfieOverlay');

            if (note) document.getElementById('selfieNote').textContent = note;

            box.hidden = false;
            resetSelfieStage();

            // Bukas na ang camera — tinanggihan ang unang larawan at
            // ito ang pangalawang hiling. Ang muling paghingi ng
            // stream dito ay mag-iiwan ng nakabukas na camera na
            // walang sinumang nagsasara.
            if (selfieStream) return;

            // getUserMedia ay HTTPS lamang (at localhost). Ang sabihing
            // "hindi ma-access ang camera" ay walang tulong; ang
            // sasabihin ay kung ano ang gagawin.
            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                closeSelfie();
                showAlert('This browser cannot open the camera. Please ask your instructor to mark you manually.', 'danger');
                return;
            }

            navigator.mediaDevices.getUserMedia({
                    video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 640 } },
                    audio: false
                })
                .then(stream => {
                    selfieStream = stream;
                    const video = document.getElementById('selfieVideo');
                    video.srcObject = stream;
                    video.play().catch(() => {});
                })
                .catch(() => {
                    closeSelfie();
                    showAlert('Camera permission was denied. Allow the camera and submit again, or ask your instructor to mark you manually.', 'danger');
                });
        }

        function resetSelfieStage() {
            document.getElementById('selfieVideo').hidden   = false;
            document.getElementById('selfieShot').hidden    = true;
            document.getElementById('selfieCapture').hidden = false;
            document.getElementById('selfieRetake').hidden  = true;
            document.getElementById('selfieSend').hidden    = true;
        }

        function closeSelfie() {
            const box = document.getElementById('selfieOverlay');
            if (!box || box.hidden) return;

            // Ang track na hindi tinigil ay ilaw ng camera na
            // nananatiling bukas pagkatapos ng lahat — sapat na iyon
            // para hindi na muling buksan ng estudyante ang link.
            if (selfieStream) {
                selfieStream.getTracks().forEach(t => t.stop());
                selfieStream = null;
            }

            document.getElementById('selfieVideo').srcObject = null;
            document.getElementById('selfieShot').removeAttribute('src');
            box.hidden = true;
        }

        let selfieData = null;

        document.getElementById('selfieCapture').addEventListener('click', function () {
            const video = document.getElementById('selfieVideo');
            if (!video.videoWidth) return;

            // Parisukat mula sa gitna, 480px — kasinlaki ng ipinapakita
            // ng .att-selfie-stage, at nasa ilalim ng hangganang
            // tinatanggap ng selfie_store(). Ang buong 1080p na frame
            // ay isang megabyte na hindi naman titingnan nang ganoon
            // kalaki kahit kailan.
            const side   = Math.min(video.videoWidth, video.videoHeight);
            const canvas = document.createElement('canvas');
            canvas.width = canvas.height = 480;

            const ctx = canvas.getContext('2d');
            ctx.drawImage(
                video,
                (video.videoWidth - side) / 2, (video.videoHeight - side) / 2, side, side,
                0, 0, 480, 480
            );

            // Hindi sinasalamin ang naka-save na larawan kahit
            // nakasalamin ang preview: ang instruktor ang titingin
            // dito, at para sa kanya ay dapat itong kamukha ng
            // nakatayo sa harap niya.
            selfieData = canvas.toDataURL('image/jpeg', 0.75);

            const shot = document.getElementById('selfieShot');
            shot.src = selfieData;
            shot.hidden = false;

            document.getElementById('selfieVideo').hidden   = true;
            document.getElementById('selfieCapture').hidden = true;
            document.getElementById('selfieRetake').hidden  = false;
            document.getElementById('selfieSend').hidden    = false;
        });

        document.getElementById('selfieRetake').addEventListener('click', function () {
            selfieData = null;
            resetSelfieStage();
        });

        document.getElementById('selfieSend').addEventListener('click', function () {
            if (!selfieData) return;

            this.disabled = true;
            document.getElementById('selfieRetake').disabled = true;

            sendAttendance(selfieData);

            // Ibinabalik agad: kapag tinanggihan ang larawan, ang
            // parehong overlay ang mananatili at kailangang magamit
            // muli ang dalawang pindutan.
            setTimeout(() => {
                this.disabled = false;
                document.getElementById('selfieRetake').disabled = false;
            }, 1200);
        });

        document.getElementById('selfieCancel').addEventListener('click', function () {
            selfieData = null;
            closeSelfie();
            showAlert('Attendance was not submitted — the photo check was cancelled.', 'warning');
        });

        // Ang linkUrl ay hindi laging kasama — ang mga mensaheng may
        // kasunod na gagawin lang (halimbawa, ang kulang na larawan) ang
        // nagdadala nito.
        function showAlert(message, type, linkUrl, linkLabel) {
            const alertContainer = document.getElementById('alertContainer');
            const alert = document.createElement('div');
            alert.className = `alert alert-${type} alert-dismissible fade show`;
            alert.innerHTML = `
                ${message}
                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
            `;

            if (linkUrl) {
                // createElement at textContent — galing sa server ang URL,
                // pero hindi ito idinidikit sa innerHTML sa itaas para
                // manatiling datos ang datos.
                const link = document.createElement('a');
                link.href = linkUrl;
                link.textContent = linkLabel || 'Open';
                link.className = 'alert-link d-block mt-2';
                alert.appendChild(link);
            }

            alertContainer.innerHTML = '';
            alertContainer.appendChild(alert);

            // Ang mensaheng may hakbang na susundan ay nananatili: hindi
            // magandang mawala ang link bago pa ito mapindot.
            if (!linkUrl) {
                setTimeout(() => {
                    if (alert.parentNode) alert.remove();
                }, 5000);
            }
        }
    </script>
<?php include __DIR__ . "/../includes/theme_toggle.php"; ?>
</body>

</html>