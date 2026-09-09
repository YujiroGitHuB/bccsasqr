<?php
header('Content-Type: application/json');
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/photo_requirement.php";
require_once __DIR__ . "/../includes/attendance_integrity.php";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$student_no = trim($_POST['student_no'] ?? '');
$short_code = trim($_POST['short_code'] ?? '');

if (empty($student_no)) {
    echo json_encode(['success' => false, 'message' => 'Student number is required']);
    exit;
}

// ── 0. Ang link muna, bago ang estudyante ─────────────────────────────────────
//
// Dati ay walang hinihinging link ang file na ito. Ang subject_code,
// required_section at instructor_id ay galing sa POST, at ang epekto
// niyon ay hindi lamang mahinang tseke — ito ay bukás na direktoryo:
// isang loop mula 025-001 hanggang 025-2000 at nasa'yo na ang pangalan,
// course, section at larawan ng bawat estudyante ng paaralan. Iyon
// mismo ang kailangan para magsumite ng attendance para sa iba.
//
// Ang short_code na ngayon ang tanging pinagkakatiwalaan, at ang klase
// ay binabasa mula sa hilera nito — parehong-pareho ng ginagawa na ng
// crud/submit_attendance.php. Ang lookup ay para sa taong may hawak ng
// link ng klase, at buhay pa ang link na iyon.
if ($short_code === '') {
    echo json_encode(['success' => false, 'message' => 'This attendance link is not valid.']);
    exit;
}

$linkStmt = $conn->prepare("
    SELECT subject_code, section, instructor_id, is_active,
           (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired
    FROM attendance_links_tbl
    WHERE short_code = ?
");
$linkStmt->bind_param("s", $short_code);
$linkStmt->execute();
$link = $linkStmt->get_result()->fetch_assoc();
$linkStmt->close();

if (!$link) {
    echo json_encode(['success' => false, 'message' => 'This attendance link is not valid.']);
    exit;
}

if ((int) $link['is_active'] !== 1) {
    echo json_encode(['success' => false, 'message' => 'This attendance link has been deactivated by your instructor.']);
    exit;
}

if ((int) $link['is_expired'] === 1) {
    echo json_encode(['success' => false, 'message' => 'This attendance link has already closed.']);
    exit;
}

$subject_code     = trim((string) $link['subject_code']);
$required_section = trim((string) $link['section']);
$instructor_id    = (int) $link['instructor_id'];

// ── 0b. Gaano karaming numero ang hinahanap mo? ───────────────────────────────
//
// Dalawang bilangan, magkaibang tanong.
//
// Ang device ay masikip: apatnapung paghahanap kada sampung minuto.
// Isang tao lamang ang naghahanap ng SARILING numero — kahit ilang
// beses siyang magkamali sa pagtipa, wala siyang dahilan para lumagpas
// dito. Ang lumalagpas ay dumadaan sa listahan.
//
// Ang IP ay maluwag: isang public IP lamang ang buong silid sa likod ng
// NAT ng paaralan, kaya ang apatnapung estudyanteng sabay-sabay na
// nagsusumite ay iisang address. Ang hinuhuli ng bilang na ito ay ang
// nag-iiskrip ng libu-libong numero — hindi ang klase.
$device_id = integrity_device_id($conn);
$ip        = integrity_client_ip();

/**
 * Isinusulat sa attendance_audit_tbl na may umabot sa hangganan.
 *
 * Ang bilangan ay humaharang nang tahimik noon: `exit` lamang, at
 * walang natitirang bakas kahit saan. Ang lumalagpas sa apatnapung
 * paghahanap ay ang pinakamalinaw na senyas na kayang ibigay ng
 * sistemang ito — may dumadaan sa listahan ng mga numero — at ito
 * ang tanging bagay na hindi nakikita ng instruktor.
 *
 * ISANG hilera kada window at hindi kada request: ang naharang ay
 * patuloy pa ring sumusubok, at hindi dapat maging aklat niya ang
 * audit. Ang parehong talaan ng bilangan ang nagbabantay nito —
 * hangganang isa sa loob ng sampung minuto, kaya ang una lamang ang
 * naisusulat.
 */
$limit_seen = function (string $bucket) use ($conn, $student_no, $short_code, $subject_code, $required_section, $instructor_id, $device_id, $ip) {
    if (!integrity_rate_ok($conn, 'lg:' . $bucket, 1, 600)) return;

    integrity_log($conn, [
        'student_no'    => $student_no,
        'short_code'    => $short_code,
        // Code at hindi pangalan: ang tanong na ito ay hindi
        // kumukuha ng subject_name mula sa link, at ang code ay
        // nakikilala pa rin ng gurong tumitingin sa listahan.
        'subject_name'  => $subject_code,
        'section'       => $required_section,
        'instructor_id' => $instructor_id,
        'device_id'     => $device_id,
        'ip'            => $ip,
        'result'        => 'lookup_limit',
    ]);
};

if (!integrity_rate_ok($conn, 'v:d:' . $device_id, 40, 600)) {
    $limit_seen('d:' . $device_id);
    echo json_encode([
        'success' => false,
        'message' => 'Too many lookups from this device. Please wait a few minutes and try again.'
    ]);
    exit;
}

if ($ip !== '' && !integrity_rate_ok($conn, 'v:i:' . $ip, 400, 600)) {
    $limit_seen('i:' . $ip);
    echo json_encode([
        'success' => false,
        'message' => 'Too many lookups from this network. Please wait a few minutes and try again.'
    ]);
    exit;
}

try {
    // ── 1. Check if student exists ────────────────────────────────────────────
    // NOTE: no TRIM() on the column — that would prevent the use of
    // the uniq_student_no index (a full scan of students_tbl). The
    // input is trimmed above, and a migration cleaned the stored
    // values.
    //
    // Kasama na ang photo_path sa tanong na ito: ito ang ipinapakita ng
    // form sa tabi ng pangalan kapag na-verify na. Isang tanong lamang,
    // kaya hindi na tinatawag ang student_photo_missing() sa ibaba —
    // pareho ng ginagawa ng crud/save_attendance.php.
    $stmt = $conn->prepare("
        SELECT s.student_no, s.fullname, s.course, s.section, p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
    ");
    $stmt->bind_param("s", $student_no);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Student number not found. Please check and try again.'
        ]);
        exit;
    }

    $student = $result->fetch_assoc();

    // Build full section e.g. "BSIT-2A" from students_tbl course + section
    $student['section'] = $student['course'] . '-' . $student['section'];

    // Ang path sa talaan ay mula sa ugat ng app ("uploads/photos/…"),
    // samantalang ang pahinang humihingi nito ay nasa /pages — kaya
    // "../" ang unahan, katulad ng isinasauli ng scanner.
    $photo_path = $student['photo_path'] ?? null;
    unset($student['photo_path']);
    $student['photo_url'] = !empty($photo_path) ? '../' . $photo_path : null;

    // ── 1b. Photo requirement ─────────────────────────────────────────────────
    // Kapareho ng scanner: kapag naka-ON ang setting, walang larawan ay
    // walang attendance. Sinasabi na rito para hindi pa punan ng estudyante
    // ang form bago siya tanggihan — pero sa crud/submit_attendance.php ang
    // harang na hindi malalampasan.
    //
    // Kapag naka-OFF naman, dumadaan pa rin siya at nakakakuha lamang ng
    // paalala. Ganoon din ang scanner: pumapasa ang scan, may babala.
    $photo_missing = empty($photo_path);

    if ($photo_missing && photo_is_required($conn)) {
        echo json_encode([
            'success'    => false,
            'code'       => 'photo_required',
            'message'    => photo_required_message(),
            'upload_url' => '../student/StudentPhotoProfile.php'
        ]);
        exit;
    }

    // ── 2. Check if student is enrolled in this subject ───────────────────────
    if (!empty($subject_code)) {
        // The collation is utf8mb4_general_ci, so the comparison is
        // already case-insensitive — UPPER() is redundant, and like
        // TRIM() it kills idx_student_no.
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
            echo json_encode([
                'success' => false,
                'message' => 'You are not enrolled in this subject.'
            ]);
            exit;
        }

        // ── 3. Check section from student_subjects_tbl (supports irreg students) ──
        $enrolled_row     = $enroll_result->fetch_assoc();
        $enrolled_section = strtoupper(trim($enrolled_row['section'])); // e.g. "2A"

        // Extract section part only from required_section (e.g. "BSIT-2A" → "2A")
        $req_parts        = explode('-', $required_section, 2);
        $req_section_only = strtoupper(trim($req_parts[1] ?? $required_section));

        if (!empty($required_section) && $enrolled_section !== $req_section_only) {
            echo json_encode([
                'success' => false,
                'message' => 'You are not in this section (' . htmlspecialchars($required_section) . ').'
            ]);
            exit;
        }
    }

    // ── 4. Check if instructor is assigned to this section ────────────────────
    if (!empty($instructor_id) && !empty($required_section)) {
        // required_section is "BSIT-2A", split to get course and section
        $parts     = explode('-', $required_section, 2); // ["BSIT", "2A"]
        $r_course  = $parts[0] ?? '';
        $r_section = $parts[1] ?? '';

        $instr = $conn->prepare("
            SELECT id FROM instructor_section_tbl
            WHERE instructor_id = ?
              AND UPPER(TRIM(course))  = UPPER(TRIM(?))
              AND UPPER(TRIM(section)) = UPPER(TRIM(?))
            LIMIT 1
        ");
        $instr->bind_param("iss", $instructor_id, $r_course, $r_section);
        $instr->execute();
        $instr_result = $instr->get_result();

        if ($instr_result->num_rows === 0) {
            echo json_encode([
                'success' => false,
                'message' => 'This attendance link is not valid for your section.'
            ]);
            exit;
        }
    }

    echo json_encode([
        'success'       => true,
        'message'       => 'Student found',
        'student'       => $student,
        // Hindi kailangan ang larawan sa ngayon, pero wala pa rin siya —
        // pinapaalala ng pahina habang maluwag pa, para may photo na siya
        // bago pa i-ON ng admin ang tuntunin.
        'photo_missing' => $photo_missing,
        'upload_url'    => $photo_missing ? '../student/StudentPhotoProfile.php' : null
    ]);

    $stmt->close();

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database error occurred'
    ]);
    error_log("Verify Student Error: " . $e->getMessage());
}

$conn->close();
