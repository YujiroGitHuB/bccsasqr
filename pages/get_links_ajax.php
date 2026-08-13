<?php
ob_start();

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

ob_clean();
header('Content-Type: application/json');

requirePermissionJson('links.manage');

if (empty($_SESSION['user_id']) || empty($_SESSION['role'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$user_id   = (int) $_SESSION['user_id'];
$user_role = $_SESSION['role'];

// ─── Cache ────────────────────────────────────────────────────────────────────
$cache_key = 'attendance_links_' . $user_id;
$cache_ttl = 600;

if (
    !isset($_GET['refresh']) &&
    isset($_SESSION[$cache_key]) &&
    (time() - $_SESSION[$cache_key]['time']) < $cache_ttl
) {
    echo json_encode(['success' => true, 'cached' => true, 'data' => $_SESSION[$cache_key]['data']]);
    exit;
}

function generateShortCode($length = 6) {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    $code  = '';
    for ($i = 0; $i < $length; $i++) {
        $code .= $chars[rand(0, strlen($chars) - 1)];
    }
    return $code;
}

// ─── 1. Fetch subjects ────────────────────────────────────────────────────────
// JOIN now uses ss.section = ist.section (from student_subjects_tbl)
// instead of st.section = ist.section (from students_tbl).
// This correctly handles irreg students and ensures links appear/disappear
// based on actual enrollment records — not the student's original section.
$subjects = [];

try {
    if ($user_role === 'admin') {
        $query = "
            SELECT DISTINCT
                s.id            AS subject_id,
                s.subject_code,
                s.subject_name,
                CONCAT(ist.course, '-', ist.section) AS section,
                u.id            AS instructor_id,
                u.name          AS instructor_name,
                CASE WHEN si.instructor_id = ? THEN 1 ELSE 0 END AS is_mine
            FROM subject_instructors_tbl si
            INNER JOIN subjects_tbl s
                ON si.subject_id = s.id
            INNER JOIN users u
                ON si.instructor_id = u.id
            INNER JOIN instructor_section_tbl ist
                ON ist.instructor_id = si.instructor_id
            INNER JOIN student_subjects_tbl ss
                ON ss.subject_code = s.subject_code
               AND ss.section = ist.section
            INNER JOIN students_tbl st
                ON st.student_no = ss.student_no
            ORDER BY is_mine DESC, ist.course, ist.section, s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $subjects[] = $row;
        }

    } elseif ($user_role === 'instructor') {
        $query = "
            SELECT DISTINCT
                s.id            AS subject_id,
                s.subject_code,
                s.subject_name,
                CONCAT(ist.course, '-', ist.section) AS section,
                u.id            AS instructor_id,
                u.name          AS instructor_name
            FROM subject_instructors_tbl si
            INNER JOIN subjects_tbl s
                ON si.subject_id = s.id
            INNER JOIN users u
                ON si.instructor_id = u.id
            INNER JOIN instructor_section_tbl ist
                ON ist.instructor_id = si.instructor_id
            INNER JOIN student_subjects_tbl ss
                ON ss.subject_code = s.subject_code
               AND ss.section = ist.section
            INNER JOIN students_tbl st
                ON st.student_no = ss.student_no
            WHERE si.instructor_id = ?
            ORDER BY ist.course, ist.section, s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $subjects[] = $row;
        }
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'DB error: ' . $e->getMessage()]);
    exit;
}

// ─── 2. Build valid keys from current subjects ────────────────────────────────
$valid_keys = [];
foreach ($subjects as $s) {
    $valid_keys[] = $s['subject_id'] . '|' . $s['section'] . '|' . $s['instructor_id'];
}

// ─── 2b. Fetch ALL active links for this instructor/admin ─────────────────────
// Must fetch ALL — not just ones matching current subjects —
// so we can deactivate orphaned links (enrollment deleted).
$all_active_links = [];

if ($user_role === 'admin') {
    $all_stmt = $conn->prepare("
        SELECT subject_id, section, instructor_id, short_code
        FROM attendance_links_tbl
        WHERE is_active = 1
    ");
    $all_stmt->execute();
} else {
    $all_stmt = $conn->prepare("
        SELECT subject_id, section, instructor_id, short_code
        FROM attendance_links_tbl
        WHERE is_active = 1 AND instructor_id = ?
    ");
    $all_stmt->bind_param("i", $user_id);
    $all_stmt->execute();
}

$all_result = $all_stmt->get_result();
while ($row = $all_result->fetch_assoc()) {
    $key = $row['subject_id'] . '|' . $row['section'] . '|' . $row['instructor_id'];
    $all_active_links[$key] = $row['short_code'];
}

// ─── 2c. Auto-deactivate links with no more enrolled students ─────────────────
$existing_links = [];
foreach ($all_active_links as $key => $short_code) {
    if (!in_array($key, $valid_keys)) {
        // No enrolled students anymore — deactivate
        $deactivate = $conn->prepare("
            UPDATE attendance_links_tbl SET is_active = 0 WHERE short_code = ?
        ");
        $deactivate->bind_param("s", $short_code);
        $deactivate->execute();
    } else {
        // Still valid — keep in map for Step 3
        $existing_links[$key] = $short_code;
    }
}

// ─── 3. Build links ───────────────────────────────────────────────────────────
$links = [];

foreach ($subjects as $subject) {
    $key = $subject['subject_id'] . '|' . $subject['section'] . '|' . $subject['instructor_id'];

    if (isset($existing_links[$key])) {
        $short_code = $existing_links[$key];
    } else {
        do {
            $short_code = generateShortCode(6);
            $chk        = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
            $chk->bind_param("s", $short_code);
            $chk->execute();
        } while ($chk->get_result()->num_rows > 0);

        $reuse = $conn->prepare("
            SELECT short_code FROM attendance_links_tbl
            WHERE subject_id = ? AND section = ? AND instructor_id = ? AND is_active = 0
            ORDER BY id DESC LIMIT 1
        ");
        $reuse->bind_param("isi", $subject['subject_id'], $subject['section'], $subject['instructor_id']);
        $reuse->execute();
        $reuse_result = $reuse->get_result();

        if ($reuse_result->num_rows > 0) {
            $old = $reuse_result->fetch_assoc();
            $upd = $conn->prepare("UPDATE attendance_links_tbl SET short_code = ?, is_active = 1 WHERE short_code = ?");
            $upd->bind_param("ss", $short_code, $old['short_code']);
            $upd->execute();
        } else {
            $ins = $conn->prepare("
                INSERT INTO attendance_links_tbl
                    (short_code, subject_id, subject_code, subject_name, section, instructor_id, instructor_name, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ");
            $ins->bind_param("sisssssi",
                $short_code,
                $subject['subject_id'],
                $subject['subject_code'],
                $subject['subject_name'],
                $subject['section'],
                $subject['instructor_id'],
                $subject['instructor_name'],
                $user_id
            );
            $ins->execute();
        }
    }

    $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http";
    $host     = $_SERVER['HTTP_HOST'];
    $base_dir = str_replace('/admin', '', dirname($_SERVER['PHP_SELF']));
    $link     = $protocol . "://" . $host . $base_dir . "/daily_attendance.php?c=" . $short_code;

    $links[] = [
        'subject'    => $subject,
        'short_code' => $short_code,
        'link'       => $link,
    ];
}

// ─── 4. Cache + respond ───────────────────────────────────────────────────────
$_SESSION[$cache_key] = ['data' => $links, 'time' => time()];

echo json_encode(['success' => true, 'cached' => false, 'data' => $links]);