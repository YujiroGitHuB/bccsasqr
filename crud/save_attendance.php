<?php
// Errors are logged, never printed: a PHP warning in the middle of this
// JSON broke the scan it belonged to, and printed the server's file
// paths to whoever was holding the phone.
error_reporting(E_ALL);
ini_set('display_errors', 0);

session_start();
include "../includes/db_connect.php";
include "../includes/auth.php";
include __DIR__ . "/../includes/permissions.php";
require_once __DIR__ . "/../includes/photo_requirement.php";
require_once __DIR__ . "/../includes/late.php";
date_default_timezone_set('Asia/Manila');

header('Content-Type: application/json');

requirePermissionJson('attendance.record');

try {
    $data = json_decode(file_get_contents('php://input'), true);

    // ── 0. What the request is trusted with ───────────────────────────────────
    // Only WHICH student and WHICH subject. Everything else used to come
    // from the request as well, and each one was a way in:
    //
    //   user_id  decided whether the scanner was an admin — so an
    //            instructor sending user_id 1 skipped the "is this
    //            subject yours?" check, and the record was filed under
    //            whoever they named.
    //   date     let a scan be filed on any day, past or future.
    //   time     let a late arrival pick their own time_in.
    //   subject  was stored as the subject NAME beside a code it need
    //            not match, so a record could claim any class.
    //
    // Who comes from the session, when from the server's clock, and the
    // subject's name from subjects_tbl.
    $student_no   = trim((string) ($data['id']           ?? ''));
    $subject_code = trim((string) ($data['subject_code'] ?? ''));
    $user_id      = (int) ($_SESSION['user_id'] ?? 0);

    // One instant for all three, so the date, the time_in and the stored
    // datetime can never straddle a second — or midnight.
    $now          = time();
    $date         = date('Y-m-d', $now);
    $time         = date('h:i:s A', $now);

    // ── 1. Validate required fields ───────────────────────────────────────────
    if ($student_no === '' || $subject_code === '' || $user_id <= 0) {
        echo json_encode([
            'success' => false,
            'message' => 'missing_data',
            'error'   => 'Required fields are missing'
        ]);
        exit;
    }

    $subj = $conn->prepare("SELECT subject_name FROM subjects_tbl WHERE subject_code = ? LIMIT 1");
    $subj->bind_param("s", $subject_code);
    $subj->execute();
    $subject = $subj->get_result()->fetch_assoc()['subject_name'] ?? null;
    $subj->close();

    if ($subject === null) {
        echo json_encode([
            'success' => false,
            'message' => 'missing_data',
            'error'   => 'That subject does not exist.'
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
    // Ang photo_path ay nasa kamay na mula sa tanong sa itaas, kaya
    // student_photo_missing() ang hindi ginagamit dito — ang setting
    // lamang ang hinihiram, at iisa ang sagot nito sa scanner at sa
    // attendance link.
    $photo_missing = empty($student_data['photo_path']);

    if (photo_is_required($conn) && $photo_missing) {
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

    // ── 7b. Late? ─────────────────────────────────────────────────────────────
    // Yes while the signed-in instructor has late marking switched on for
    // this subject today (includes/late.php).
    $is_late   = late_scan_now($conn, $user_id, $subject_code) ? 1 : 0;
    $lateReady = late_ready($conn);

    // ── 8. Insert attendance record ───────────────────────────────────────────
    $datetime = date('Y-m-d H:i:s', $now);

    // is_late only once the column exists — without it this INSERT
    // would fail for every scan.
    $lateInsCol = $lateReady ? ', is_late' : '';
    $lateInsVal = $lateReady ? ', ?' : '';

    $insert = $conn->prepare("
        INSERT INTO attendance_tbl
            (user_id, date, student_no, name, course, section, subject, instructor, time_in$lateInsCol)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?$lateInsVal)
    ");
    if (!$insert) throw new Exception("Insert prepare failed: " . $conn->error);

    $insParams = [
        $user_id,
        $datetime,
        $student_no,
        $student_data['fullname'],
        $student_data['course'],
        $student_data['section'],
        $subject,
        $instructor,
        $time
    ];
    if ($lateReady) $insParams[] = $is_late;

    $insert->bind_param("issssssss" . ($lateReady ? 'i' : ''), ...$insParams);

    if ($insert->execute()) {
        echo json_encode([
            'success'   => true,
            'message'   => 'saved',
            'late'       => (bool) $is_late,
            // What was stored, so the scanner shows the server's date and
            // time — not the phone's, which is no longer sent.
            'date'       => $date,
            'time_in'    => $time,
            'subject'    => $subject,
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
    // The detail goes to the server log. The phone gets a sentence — the
    // stack trace it used to get named every file and path on the server.
    error_log('save_attendance: ' . $e->getMessage() . ' | ' . $e->getTraceAsString());
    echo json_encode([
        'success' => false,
        'message' => 'error',
        'error'   => 'Could not save attendance. Please try again.'
    ]);
}
