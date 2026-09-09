<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/photo_requirement.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";
date_default_timezone_set('Asia/Manila');
header('Content-Type: application/json');

// Ang tseke ng nakasarang form ay nasa ibaba na, pagkatapos ng
// $audit: ang labasang hindi naitatala ay isang bagay na nangyari
// nang hindi nakikita ng instruktor, at wala nang dahilan para
// maunang tumakbo ito kaysa sa dalawang linyang naghahanda ng talaan.

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
$today      = date('Y-m-d');

// Sino ang may hawak ng telepono. Ang device_id ay cookie na
// pinipirmahan ng server; ang fingerprint ay galing sa browser at
// hindi pinagkakatiwalaan — pang-talaan lamang, para may
// masusundan kapag binura ang cookie.
$device_id   = integrity_device_id($conn);
$fingerprint = substr(preg_replace('/[^a-f0-9]/', '', strtolower($_POST['fp'] ?? '')), 0, 16);
$client_ip   = integrity_client_ip();

/**
 * Isang hilera sa attendance_audit_tbl para sa pagsusumiteng ito.
 *
 * Nakatayo ito BAGO ang lahat ng tseke, at hindi pagkatapos ng link.
 * Noong nasa ibaba pa ito, anim na labasan ang dumaraan nang walang
 * naiiwang bakas — hindi valid na link, patay na link, sarado nang
 * link, walang ganoong numero, kulang ang larawan, at ang nabigong
 * INSERT. Ang bawat isa sa mga iyon ay isang tao na sumubok, at ang
 * pahinang tumitingin sa talaan ay nagsasabing walang nangyari.
 *
 * Ang tatlong hawak ng klase ay reference: hindi pa alam ang mga ito
 * habang tumatakbo ang unang tseke, at napupuno kapag nabasa na ang
 * hilera ng link. Ang naunang naitala ay may NULL doon — tama iyon,
 * dahil sa mga labasang iyon ay wala pang klaseng masasabi.
 */
$subject_name  = null;
$full_section  = null;
$instructor_id = null;

$audit = function (string $result) use (
    $conn, $student_no, $short_code, &$subject_name, &$full_section,
    &$instructor_id, $device_id, $fingerprint, $client_ip
) {
    // Dalawa sa mga kahihinatnan ang kayang ulitin ng isang script
    // nang walang hangganan: walang bilangan ang pagsusumite, hindi
    // tulad ng paghahanap sa crud/verify_student.php. Kung walang
    // takip dito, ang mismong talaang ginawa para makita ang
    // pang-aabuso ay siyang magiging sasakyan nito — sampung
    // megabyte lamang ang database.
    //
    // Limang hilera kada sampung minuto kada device: sapat para
    // makita mong may nangyayari, at kulang para maging pinsala.
    // Ang bilang sa tile ay maliit kaysa sa totoo kapag umabot dito;
    // ang mas mabuting sagot ay bilangan sa pagsusumite mismo, at
    // wala pa iyon.
    if (in_array($result, ['no_student', 'bad_link'], true)
        && !integrity_rate_ok($conn, 'lg:s:' . $result . ':' . $device_id, 5, 600)) {
        return;
    }

    integrity_log($conn, [
        'student_no'    => $student_no,
        'short_code'    => $short_code,
        'subject_name'  => $subject_name,
        'section'       => $full_section,
        'instructor_id' => $instructor_id,
        'device_id'     => $device_id,
        'fingerprint'   => $fingerprint,
        'ip'            => $client_ip,
        'result'        => $result,
    ]);
};

// ── Check if form is locked ───────────────────────────────────────────────────
$result    = $conn->query("SELECT setting_value FROM attendance_settings WHERE setting_key = 'form_locked'");
$is_locked = 0;
if ($result && $result->num_rows > 0) {
    $row       = $result->fetch_assoc();
    $is_locked = (int)$row['setting_value'];
}

if ($is_locked) {
    $audit('form_locked');
    echo json_encode(['success' => false, 'message' => 'Attendance form is currently locked. Please contact your instructor.']);
    exit();
}

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
$linkStmt = $conn->prepare("
    SELECT subject_id, subject_code, subject_name, section, instructor_id, instructor_name,
           is_active,
           (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired
    FROM attendance_links_tbl
    WHERE short_code = ?
");
$linkStmt->bind_param("s", $short_code);
$linkStmt->execute();
$linkResult = $linkStmt->get_result();

if ($linkResult->num_rows === 0) {
    // Walang ganoong short_code. Ang link ay ibinibigay bilang QR at
    // hindi tinitipa, kaya ang paulit-ulit nito ay hindi pagkakamali
    // sa pagtipa — may humuhula.
    $audit('bad_link');
    echo json_encode(['success' => false, 'message' => 'This attendance link is not valid.']);
    exit();
}

$link = $linkResult->fetch_assoc();

if ((int)$link['is_active'] !== 1) {
    $audit('link_off');
    echo json_encode(['success' => false, 'message' => 'This attendance link has been deactivated by your instructor.']);
    exit();
}

if ((int)$link['is_expired'] === 1) {
    // Ang tanong na hindi masasagot noon: sino ang dumating pagkasara.
    $audit('link_expired');
    echo json_encode(['success' => false, 'message' => 'This attendance link has already closed. Please ask your instructor for a new one.']);
    exit();
}

$subject_id      = $link['subject_id'];
$subject_code    = trim($link['subject_code']);
$subject_name    = trim($link['subject_name']);
$full_section    = trim($link['section']);   // "BSIT-1A"
$instructor_id   = (int)$link['instructor_id'];
$instructor_name = trim($link['instructor_name']);

// Mula rito ay alam na ng $audit kung anong klase ito: reference ang
// hawak nito sa tatlong variable sa itaas, kaya may pangalan na ng
// asignatura ang bawat hilerang isusulat pagkatapos ng puntong ito.

// ── 1. Get student info from DB ───────────────────────────────────────────────
$stmt = $conn->prepare("SELECT student_no, fullname, course, section FROM students_tbl WHERE student_no = ?");
$stmt->bind_param("s", $student_no);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    // Walang ganoong numero sa buong paaralan. Ang estudyanteng
    // nagkamali ng isang digit ay isa nito; ang tatlumpu nito sa loob
    // ng limang minuto mula sa isang device ay hindi na.
    $audit('no_student');
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
    $audit('photo_missing');
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

// ── 2b. Isang device, isang estudyante ────────────────────────────────────────
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
    $audit('ok');
    echo json_encode(['success' => true, 'message' => 'Attendance submitted successfully for ' . $subject_name . '!']);
} else {
    // Pumasa siya sa bawat tseke at hindi pa rin siya naitala. Kung
    // wala ito, ang estudyanteng nagrereklamong nagsumite siya ay
    // walang katunayan, at ang talaan ay mukhang hindi siya sumubok.
    $audit('save_failed');
    echo json_encode(['success' => false, 'message' => 'Failed to submit attendance. Please try again.']);
}

$insert->close();
$conn->close();
