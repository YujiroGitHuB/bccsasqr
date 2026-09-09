<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/photo_requirement.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";
date_default_timezone_set('Asia/Manila');
header('Content-Type: application/json');

// ── Check if form is locked ───────────────────────────────────────────────────
$result    = $conn->query("SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");
$is_locked = 0;
if ($result && $result->num_rows > 0) {
    $row       = $result->fetch_assoc();
    $is_locked = (int)$row['setting_value'];
}

if ($is_locked) {
    echo json_encode(['success' => false, 'message' => 'Attendance form is currently locked. Please contact your instructor.']);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit();
}

// ── Validate required fields ──────────────────────────────────────────────────
$required = ['student_no', 'short_code'];
foreach ($required as $field) {
    if (empty($_POST[$field])) {
        echo json_encode(['success' => false, 'message' => ucfirst(str_replace('_', ' ', $field)) . ' is required']);
        exit();
    }
}

$student_no = trim($_POST['student_no']);
$short_code = trim($_POST['short_code']);
$room_input = trim($_POST['room_code'] ?? '');
$selfie_raw = (string) ($_POST['selfie'] ?? '');
$today      = date('Y-m-d');

// Sino ang may hawak ng telepono. Ang device_id ay cookie na
// pinipirmahan ng server; ang fingerprint ay galing sa browser at
// hindi pinagkakatiwalaan — pang-talaan lamang, para may
// masusundan kapag binura ang cookie.
$device_id   = integrity_device_id($conn);
$fingerprint = substr(preg_replace('/[^a-f0-9]/', '', strtolower($_POST['fp'] ?? '')), 0, 16);
$client_ip   = integrity_client_ip();

// ── 0. Ang link ang nagsasabi kung anong klase ito ────────────────────────────
//
// Dati ay galing sa POST ang subject, section at instructor, at hindi
// tinitingnan ng file na ito ang link kahit kailan. Dalawang bagay ang
// naidudulot niyon:
//
//   1. Walang saysay ang deactivate. Ang estudyanteng nakabukas na ang
//      form ay makakapagsumite pa rin pagkatapos mong patayin ang link.
//   2. Hindi kailangan ng link. Sinumang minsang nakakita ng mga
//      halaga ay makakapag-POST nito nang diretso, magpakailanman.
//
// Ang expiration ay walang kabuluhan kung hindi ito sinusuri dito —
// kaya ang short_code na ang tanging pinagkakatiwalaan, at ang lahat
// ng iba pa ay binabasa mula sa hilera nito.
//
// Ang paghahambing ng oras ay nasa SQL: ang orasan ng database ang
// nagtakda ng expires_at (tingnan ang crud/set_link_expiry.php), kaya
// ang parehong orasan din ang dapat magsabing lumipas na ito.
// SELECT * at hindi nakalistang column, gaya ng ginagawa ng
// pages/daily_attendance.php: ang require_room_code at
// room_code_secret ay dumarating kasama ng isang migration, at ang
// nakalistang column na wala pa ay hindi degraded na tampok kundi
// nabasag na pagsusumite para sa buong paaralan. Binabasa ang
// dalawa sa ibaba na may ?? — walang code sa harapan hangga't
// hindi pa napapatakbo ang SQL.
$linkStmt = $conn->prepare("
    SELECT *,
           (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired
    FROM attendance_links_tbl
    WHERE short_code = ?
");
$linkStmt->bind_param("s", $short_code);
$linkStmt->execute();
$linkResult = $linkStmt->get_result();

if ($linkResult->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'This attendance link is not valid.']);
    exit();
}

$link = $linkResult->fetch_assoc();

if ((int)$link['is_active'] !== 1) {
    echo json_encode(['success' => false, 'message' => 'This attendance link has been deactivated by your instructor.']);
    exit();
}

if ((int)$link['is_expired'] === 1) {
    echo json_encode(['success' => false, 'message' => 'This attendance link has already closed. Please ask your instructor for a new one.']);
    exit();
}

$subject_id      = $link['subject_id'];
$subject_code    = trim($link['subject_code']);
$subject_name    = trim($link['subject_name']);
$full_section    = trim($link['section']);   // "BSIT-1A"
$instructor_id   = (int)$link['instructor_id'];
$instructor_name = trim($link['instructor_name']);

/**
 * Isang hilera sa attendance_audit_tbl para sa pagsusumiteng ito.
 *
 * Isinusulat sa bawat labasang may kinalaman sa pagkakakilanlan —
 * hindi lamang ang pumasa. Ang tinanggihan ang siyang balita: ang
 * anim na 'device_reuse' sa loob ng isang minuto ay hindi hinuha ng
 * instruktor, nakasulat iyon.
 */
$audit = function (string $result, ?string $selfie_path = null) use (
    $conn, $student_no, $short_code, $subject_name, $full_section,
    $instructor_id, $device_id, $fingerprint, $client_ip
) {
    integrity_log($conn, [
        'student_no'    => $student_no,
        'short_code'    => $short_code,
        'subject_name'  => $subject_name,
        'section'       => $full_section,
        'instructor_id' => $instructor_id,
        'device_id'     => $device_id,
        'fingerprint'   => $fingerprint,
        'ip'            => $client_ip,
        'selfie_path'   => $selfie_path,
        'result'        => $result,
    ]);
};

// ── 1. Get student info from DB ───────────────────────────────────────────────
$stmt = $conn->prepare("SELECT student_no, fullname, course, section FROM students_tbl WHERE student_no = ?");
$stmt->bind_param("s", $student_no);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Student not found']);
    exit();
}
$student = $result->fetch_assoc();

// ── 1b. Photo requirement ─────────────────────────────────────────────────────
// Ang parehong tuntuning ipinapatupad ng scanner (crud/save_attendance.php),
// dahil ang link ay isa ring pintuan papasok ng attendance. Dito ang tunay
// na tseke: ang tseke sa crud/verify_student.php ay para lamang maaga
// malaman ng estudyante — maaari itong lampasan ng sinumang mag-POST nang
// diretso rito.
if (photo_is_required($conn) && student_photo_missing($conn, $student_no)) {
    echo json_encode([
        'success'    => false,
        'code'       => 'photo_required',
        'message'    => photo_required_message(),
        // Kaugnay sa pages/daily_attendance.php, ang tanging tumatawag —
        // gaya rin ng ibinabalik ng crud/verify_student.php.
        'upload_url' => '../student/StudentPhotoProfile.php'
    ]);
    exit();
}

// ── 2. Check enrollment ───────────────────────────────────────────────────────
$enroll = $conn->prepare("
    SELECT section
    FROM student_subjects_tbl
    WHERE student_no   = ?
      AND subject_code = ?
    LIMIT 1
");
$enroll->bind_param("ss", $student_no, $subject_code);
$enroll->execute();
$enroll_result = $enroll->get_result();

if ($enroll_result->num_rows === 0) {
    $audit('not_enrolled');
    echo json_encode([
        'success' => false,
        'message' => 'You are not enrolled in ' . $subject_name . '. Please contact your instructor.'
    ]);
    exit();
}

$enroll_data            = $enroll_result->fetch_assoc();
$enrolled_section_raw   = trim($enroll_data['section']); // could be "BSIT-1A" or "1A"

// ✅ KEY FIX: attendance_tbl stores course and section as SEPARATE columns
// students_tbl already has correct course (e.g. "BSIT")
// We must store section as raw "1A" — NOT "BSIT-1A"
$course = $student['course']; // "BSIT" from students_tbl — always correct

// Split section if it contains course prefix (e.g. "BSIT-1A" → "1A")
if (strpos($enrolled_section_raw, '-') !== false) {
    $parts           = explode('-', $enrolled_section_raw, 2);
    $section_to_save = trim($parts[1]); // "1A"
} else {
    $section_to_save = $enrolled_section_raw; // already raw "1A"
}

// ── 2b. Nasa loob ka ba ng silid? ─────────────────────────────────────────────
//
// Anim na digit na nagpapalit kada tatlumpung segundo, ipinapakita ng
// instruktor sa projector o pisara. Ang link ay naipapasa sa group
// chat; ang code ay hindi — sa oras na maipadala mo ito, patay na.
//
// Ito lamang ang tsekeng humihingi ng bagay na hindi kayang dalhin
// palabas ng silid. Ang lahat ng iba pa ay tumitingin sa isang bagay
// na kasama mo saanman.
//
// Naka-OFF ito sa bawat link maliban kung binuksan ng instruktor
// (tingnan ang crud/set_room_code.php) — walang klaseng biglang
// mahaharangan matapos i-apply ang migration.
if ((int) ($link['require_room_code'] ?? 0) === 1) {
    $secret = (string) ($link['room_code_secret'] ?? '');

    if ($room_input === '') {
        echo json_encode([
            'success' => false,
            'code'    => 'room_code_required',
            'message' => 'Enter the 6-digit code your instructor is showing in class.'
        ]);
        exit();
    }

    if ($secret === '' || !room_code_valid($secret, $room_input)) {
        $audit('bad_room_code');
        echo json_encode([
            'success' => false,
            'code'    => 'room_code_bad',
            // Hindi sinasabi kung mali ang code o lumipas na ito.
            // Magkaiba ang dalawa para sa taong nasa labas, at ang
            // pagkakaibang iyon ay tulong sa paghula.
            'message' => 'That code is not correct right now. Check the screen again — it changes every 30 seconds.'
        ]);
        exit();
    }
}

// ── 2c. Isang device, isang estudyante ────────────────────────────────────────
//
// Ang pinakamalaking butas ay hindi teknikal: hawak mo ang link,
// i-type mo ang numero ng kaklase mo, tapos. Lumalabas pa nga ang
// pangalan at mukha niya bilang katiyakang tama ang na-type mo.
// Sampung segundo kada tao, at kayang isumite ng isang telepono ang
// buong klase bago pa matapos ang unang tawag ng pangalan.
//
// Ang cookie ang sumasagot. Hindi ito hindi malalampasan — kaya
// itong burahin, o gumamit ng incognito — pero ang bawat isa niyon
// ay dagdag na hakbang kada kaklase, at doon nagigiba ang gawain:
// hindi na ito sampung segundo. Ang natitirang determinado ay
// nasusulat sa attendance_audit_tbl at nakikita sa
// pages/attendance_integrity.php.
if (integrity_setting($conn, 'device_binding', '1') === '1') {
    $other = integrity_device_conflict($conn, $device_id, $short_code, $student_no);

    if ($other !== null) {
        $audit('device_reuse');
        echo json_encode([
            'success' => false,
            'code'    => 'device_reuse',
            // Hindi pinapangalanan kung sino ang naunang nagsumite:
            // hindi kailangang malaman ng kahit sinong may hawak ng
            // telepono kung sino ang gumamit nito bago siya. Nasa
            // audit trail iyon, para sa instruktor.
            'message' => 'This device has already recorded attendance for another student today. '
                       . 'Each student submits from their own phone — please ask your instructor to mark you manually.'
        ]);
        exit();
    }
}

// ── 3. Check for duplicate attendance today ───────────────────────────────────
$dup = $conn->prepare("
    SELECT id FROM attendance_tbl
    WHERE student_no = ? AND date = ? AND subject = ?
    LIMIT 1
");
$dup->bind_param("sss", $student_no, $today, $subject_name);
$dup->execute();

if ($dup->get_result()->num_rows > 0) {
    $audit('duplicate');
    echo json_encode([
        'success' => false,
        'message' => 'You have already submitted your attendance for ' . $subject_name . ' today.'
    ]);
    exit();
}

// ── 3b. Ang paminsan-minsang hiling ng mukha ──────────────────────────────────
//
// May larawan na sa talaan ang bawat estudyante (ito ang ipinipilit
// ng require_student_photo). Ang tanong na hindi pa naitatanong ay
// kung ang mukhang iyon ang nasa harap ng telepono ngayon.
//
// Hindi lahat ay tinatanong — mabigat ang camera sa isang libreng
// hosting, at ang paghingi sa bawat isa ay pagbabago ng buong
// karanasan para hulihin ang iilan. Ang bahagdan ay nasa Settings, at
// ang pagpili ay DETERMINISTIKO: pareho ang sagot para sa parehong
// estudyante sa parehong link sa buong araw. Kung random ito kada
// request, ang kailangan lamang gawin ay mag-refresh hanggang hindi ka
// na tanungin.
//
// Ang natitirang pumapasok dito nang hindi napili ay ang mga device na
// nakapagsumite na para sa tatlo o higit pang tao ngayong linggo —
// iyon mismo ang huwarang hinahanap.
$selfie_rate  = (int) integrity_setting($conn, 'selfie_spot_rate', '0');
$device_reach = integrity_device_reach($conn, $device_id);
$selfie_path  = null;

if (selfie_is_required($conn, $student_no, $short_code, $selfie_rate, $device_reach)) {
    if ($selfie_raw === '') {
        echo json_encode([
            'success' => false,
            'code'    => 'selfie_required',
            'message' => 'Random check: please take a quick photo of yourself to confirm it is you.'
        ]);
        exit();
    }

    $saved = selfie_store($selfie_raw, $student_no);

    if ($saved['path'] === null) {
        echo json_encode([
            'success' => false,
            'code'    => 'selfie_required',
            'message' => $saved['error']
        ]);
        exit();
    }

    $selfie_path = $saved['path'];
}

// ── 4. Insert attendance record ───────────────────────────────────────────────
// ✅ course = "BSIT", section = "1A" — stored separately so all queries match
$time_in = date('h:i:s A');
$name    = $student['fullname'];

$insert = $conn->prepare("
    INSERT INTO attendance_tbl
        (date, student_no, name, course, section, subject, instructor, time_in, user_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
");
$insert->bind_param(
    "ssssssssi",
    $today,
    $student_no,
    $name,
    $course,           // "BSIT"  ← from students_tbl
    $section_to_save,  // "1A"    ← split from enrollment section
    $subject_name,
    $instructor_name,
    $time_in,
    $instructor_id
);

if ($insert->execute()) {
    // Pagkatapos ng INSERT at hindi bago: ang 'ok' sa audit ay
    // nangangahulugang may attendance row talaga. Ito rin ang binibilang
    // ng integrity_device_conflict() bukas — kung isinulat ito bago pa
    // ang INSERT, ang isang nabigong pagsusumite ay magsasara ng device
    // para sa taong hindi naman naitala.
    $audit('ok', $selfie_path);
    echo json_encode(['success' => true, 'message' => 'Attendance submitted successfully for ' . $subject_name . '!']);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to submit attendance. Please try again.']);
}

$insert->close();
$conn->close();
