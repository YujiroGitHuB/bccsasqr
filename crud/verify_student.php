<?php
header('Content-Type: application/json');
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/photo_requirement.php";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$student_no       = trim($_POST['student_no']       ?? '');
$subject_code     = trim($_POST['subject_code']     ?? '');
$required_section = trim($_POST['required_section'] ?? '');
$instructor_id    = trim($_POST['instructor_id']    ?? '');

if (empty($student_no)) {
    echo json_encode(['success' => false, 'message' => 'Student number is required']);
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
?>