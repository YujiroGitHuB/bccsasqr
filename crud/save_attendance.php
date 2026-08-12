<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

session_start();
include "../includes/db_connect.php";
include "../includes/auth.php";
date_default_timezone_set('Asia/Manila');

header('Content-Type: application/json');

try {
    $data = json_decode(file_get_contents('php://input'), true);

    $date         = $data['date']         ?? '';
    $student_no   = $data['id']           ?? '';
    $subject      = $data['subject']      ?? '';
    $subject_code = $data['subject_code'] ?? '';
    $time         = $data['time']         ?? date('h:i:s A');
    $user_id      = $data['user_id']      ?? '';

    // ── 1. Validate required fields ───────────────────────────────────────────
    if (empty($student_no) || empty($subject) || empty($user_id)) {
        echo json_encode([
            'success' => false,
            'message' => 'missing_data',
            'error'   => 'Required fields are missing'
        ]);
        exit;
    }

    // ── 2. Check if user is admin ─────────────────────────────────────────────
    $is_admin   = false;
    $role_check = $conn->prepare("SELECT role FROM users WHERE id = ?");
    if (!$role_check) throw new Exception("Prepare failed: " . $conn->error);

    $role_check->bind_param("i", $user_id);
    $role_check->execute();
    $role_result = $role_check->get_result();

    if ($role_result->num_rows > 0) {
        $role_data = $role_result->fetch_assoc();
        $is_admin  = ($role_data['role'] === 'admin');
    }

    // ── 3. Validate instructor is assigned to this subject ────────────────────
    if (!$is_admin) {
        $subject_auth_check = $conn->prepare("
            SELECT si.id
            FROM subject_instructors_tbl si
            INNER JOIN subjects_tbl s ON s.id = si.subject_id
            WHERE s.subject_code   = ?
              AND si.instructor_id = ?
            LIMIT 1
        ");
        if (!$subject_auth_check) throw new Exception("Subject auth check prepare failed: " . $conn->error);

        $subject_auth_check->bind_param("si", $subject_code, $user_id);
        $subject_auth_check->execute();

        if ($subject_auth_check->get_result()->num_rows === 0) {
            echo json_encode([
                'success' => false,
                'message' => 'not_authorized',
                'error'   => "Subject '$subject' is not assigned to you. Please contact admin."
            ]);
            exit;
        }
    }

    // ── 4. Validate student exists & fetch details + photo ────────────────────
    $student_check = $conn->prepare("
        SELECT s.student_no, s.fullname, s.course, s.section, p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
    ");
    if (!$student_check) throw new Exception("Student check prepare failed: " . $conn->error);

    $student_check->bind_param("s", $student_no);
    $student_check->execute();
    $student_result = $student_check->get_result();

    if ($student_result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'student_not_found',
            'error'   => "Student $student_no not found in database"
        ]);
        exit;
    }

    $student_data = $student_result->fetch_assoc();
    $name   = $student_data['fullname'];
    $course = $student_data['course'];

    // ── 4b. Photo requirement ─────────────────────────────────────────────────
    // The photo is the scanner's only visual proof of identity. With the
    // setting ON, a scan does not go through without one. With it OFF the
    // scan proceeds but a warning is sent to the scanner, so the
    // instructor knows they cannot confirm who is in front of them. The
    // default is OFF — see the migration for why.
    $photo_missing = empty($student_data['photo_path']);

    $require_photo = false;
    $photo_setting = $conn->query("
        SELECT setting_value
        FROM attendance_settings
        WHERE setting_key = 'require_student_photo'
        LIMIT 1
    ");
    if ($photo_setting && $photo_setting->num_rows > 0) {
        $require_photo = ($photo_setting->fetch_assoc()['setting_value'] === '1');
    }

    if ($require_photo && $photo_missing) {
        echo json_encode([
            'success' => false,
            'message' => 'photo_required',
            'name'    => $name,
            'error'   => "$name has no photo on file. Ask the admin to upload one before scanning."
        ]);
        exit;
    }

    // ── 5. Check if student is enrolled in this subject ───────────────────────
    $enroll_check = $conn->prepare("
        SELECT section
        FROM student_subjects_tbl
        WHERE student_no   = ?
          AND subject_code = ?
        LIMIT 1
    ");
    if (!$enroll_check) throw new Exception("Enrollment check prepare failed: " . $conn->error);

    $enroll_check->bind_param("ss", $student_no, $subject_code);
    $enroll_check->execute();
    $enroll_result = $enroll_check->get_result();

    if ($enroll_result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'not_enrolled',
            'error'   => "$name is not enrolled in $subject"
        ]);
        exit;
    }

    // Use section from enrollment table — correct per subject
    $enroll_data = $enroll_result->fetch_assoc();
    $raw_section = $enroll_data['section'];

    // Strip course prefix if present (e.g., "BSIT-2A" → "2A")
    if (preg_match('/^[A-Z]+-(.+)$/', $raw_section, $matches)) {
        $student_data['section'] = $matches[1];
    } else {
        $student_data['section'] = $raw_section;
    }

    // ── 6. Check for duplicate entry (same subject + same date) ───────────────
    $dup_check = $conn->prepare("
        SELECT id
        FROM attendance_tbl
        WHERE student_no = ?
          AND subject    = ?
          AND DATE(date) = ?
        LIMIT 1
    ");
    if (!$dup_check) throw new Exception("Duplicate check prepare failed: " . $conn->error);

    $dup_check->bind_param("sss", $student_no, $subject, $date);
    $dup_check->execute();

    if ($dup_check->get_result()->num_rows > 0) {
        echo json_encode([
            'success' => false,
            'message' => 'already_marked'
        ]);
        exit;
    }

    // ── 7. Get instructor name ────────────────────────────────────────────────
    $inst = $conn->prepare("SELECT name FROM users WHERE id = ?");
    if (!$inst) throw new Exception("Instructor fetch prepare failed: " . $conn->error);

    $inst->bind_param("i", $user_id);
    $inst->execute();
    $instructor = $inst->get_result()->fetch_assoc()['name'];

    // ── 8. Insert attendance record ───────────────────────────────────────────
    $datetime = $date . ' ' . date('H:i:s');

    $insert = $conn->prepare("
        INSERT INTO attendance_tbl
            (user_id, date, student_no, name, course, section, subject, instructor, time_in)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    if (!$insert) throw new Exception("Insert prepare failed: " . $conn->error);

    $insert->bind_param(
        "issssssss",
        $user_id,
        $datetime,
        $student_no,
        $student_data['fullname'],
        $student_data['course'],
        $student_data['section'],
        $subject,
        $instructor,
        $time
    );

    if ($insert->execute()) {
        echo json_encode([
            'success'   => true,
            'message'   => 'saved',
            'name'      => $student_data['fullname'],
            'course'    => $student_data['course'],
            'section'   => $student_data['section'],
            'photo_url' => !empty($student_data['photo_path'])
                ? '../' . $student_data['photo_path']
                : null,
            // Attendance went in, but there is no face to show — tell the
            // scanner so it can warn.
            'photo_missing' => $photo_missing,
        ]);
    } else {
        throw new Exception("Insert execute failed: " . $insert->error);
    }

    $dup_check->close();
    $insert->close();
    $conn->close();
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'error',
        'error'   => $e->getMessage(),
        'trace'   => $e->getTraceAsString()
    ]);
}
