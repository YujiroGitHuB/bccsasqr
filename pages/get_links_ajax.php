<?php
ob_start();

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/links.php";

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
    // Ang mabigat na JOIN ang naka-cache — HINDI ang expiry. Sampung
    // minuto ang TTL, at ang link na may isang oras na buhay ay
    // magpapakita ng maling countdown sa buong panahong iyon (o
    // magmumukhang buhay pa gayong patay na). Isang magaan na tanong
    // ang nagpapasariwa nito.
    $cached = attach_link_expiry($conn, $_SESSION[$cache_key]['data']);
    echo json_encode(['success' => true, 'cached' => true, 'data' => $cached]);
    exit;
}

/**
 * Idinidikit ang kalagayan ng expiry sa bawat link.
 *
 * Ang bawat halaga ay galing sa database — kasama ang "ngayon". Ang
 * file na ito, ang daily_attendance.php at ang deactivate_link.php
 * ay walang date_default_timezone_set samantalang meron ang
 * submit_attendance.php; kung PHP ang magkukwenta ng natitirang
 * oras, ilang oras ang pagkakaiba ng sinasabi ng card sa aktuwal na
 * tinatanggap ng server. Isang orasan lang: NOW().
 */
function attach_link_expiry(mysqli $conn, array $links): array {
    if (empty($links)) return $links;

    $codes = array_column($links, 'short_code');
    $marks = implode(',', array_fill(0, count($codes), '?'));

    // Kasama na rito ang require_room_code: parehong hilera, at ang
    // card ay kailangang malaman kung nakabukas ang switch bago pa
    // ito maipinta. Isang tanong pa para lamang sa isang tinyint ay
    // isang round trip sa isang remote na database kada pag-load.
    $stmt = $conn->prepare("
        SELECT short_code,
               expires_at,
               require_room_code,
               (expires_at IS NOT NULL AND expires_at <= NOW())  AS is_expired,
               TIMESTAMPDIFF(SECOND, NOW(), expires_at)          AS expires_in,
               DATE_FORMAT(expires_at, '%b %e, %Y %l:%i %p')     AS expires_label
        FROM attendance_links_tbl
        WHERE short_code IN ($marks)
    ");
    $stmt->bind_param(str_repeat('s', count($codes)), ...$codes);
    $stmt->execute();

    $byCode = [];
    $res    = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $byCode[$row['short_code']] = $row;
    }

    foreach ($links as &$l) {
        $e = $byCode[$l['short_code']] ?? null;

        $l['expires_at']    = $e['expires_at']    ?? null;
        $l['expires_label'] = $e['expires_label'] ?? null;
        $l['expires_in']    = ($e && $e['expires_in'] !== null) ? (int) $e['expires_in'] : null;
        $l['is_expired']    = $e ? ((int) $e['is_expired'] === 1) : false;
        $l['room_code']     = $e ? ((int) $e['require_room_code'] === 1) : false;
    }
    unset($l);

    return $links;
}

// Ang generateShortCode() ay lumipat sa includes/links.php bilang
// link_generate_code(): tatlong file na ang gumagawa ng code, at ang
// pagsusuri kung libre pa ito ay dapat isang beses lang naisulat.

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

// is_stale: nag-expire sa NAUNANG araw. Tingnan ang 2c.
$stale_sql = "(expires_at IS NOT NULL AND DATE(expires_at) < CURDATE()) AS is_stale";

if ($user_role === 'admin') {
    $all_stmt = $conn->prepare("
        SELECT subject_id, section, instructor_id, short_code, $stale_sql
        FROM attendance_links_tbl
        WHERE is_active = 1
    ");
    $all_stmt->execute();
} else {
    $all_stmt = $conn->prepare("
        SELECT subject_id, section, instructor_id, short_code, $stale_sql
        FROM attendance_links_tbl
        WHERE is_active = 1 AND instructor_id = ?
    ");
    $all_stmt->bind_param("i", $user_id);
    $all_stmt->execute();
}

$all_result = $all_stmt->get_result();
while ($row = $all_result->fetch_assoc()) {
    $key = $row['subject_id'] . '|' . $row['section'] . '|' . $row['instructor_id'];
    $all_active_links[$key] = [
        'short_code' => $row['short_code'],
        'is_stale'   => (int) $row['is_stale'] === 1,
    ];
}

// ─── 2c. Auto-deactivate links with no more enrolled students ─────────────────
//         + bagong code para sa mga nag-expire noong nakaraang araw
//
// Walang cron sa hosting na ito, kaya walang tumatakbo sa mismong
// sandali ng pag-expire — isang WHERE clause lang ang expiry,
// sinusuri kapag may nagtanong. Ang pinakamalapit na posibleng
// "awtomatiko" ay ito: sa susunod na pagbukas ng pahina.
//
// Bakit sa naunang araw at hindi kaagad pagkatapos mag-expire: ang
// link na nagsara kaninang alas-otso ay maaaring kailanganin pang
// palawigin ngayong hapon (natagalan ang klase, may hindi
// nakapag-scan) — at ang pagpapalawig ay may saysay lamang kung
// kaparehong URL pa rin ang hawak ng mga estudyante. Ibang araw,
// ibang klase: doon na dapat mamatay ang lumang URL.
//
// Walang expiry ang bagong code hangga't hindi ka nagtatakda —
// hindi minana ang luma, dahil hindi alam ng sistema kung kailan
// ang susunod mong klase.
$existing_links = [];
$rotated        = [];

foreach ($all_active_links as $key => $info) {
    $short_code = $info['short_code'];

    if (!in_array($key, $valid_keys)) {
        // No enrolled students anymore — deactivate
        $deactivate = $conn->prepare("
            UPDATE attendance_links_tbl SET is_active = 0 WHERE short_code = ?
        ");
        $deactivate->bind_param("s", $short_code);
        $deactivate->execute();
        continue;
    }

    if ($info['is_stale']) {
        $new_code = link_generate_code($conn);
        $rot = $conn->prepare("
            UPDATE attendance_links_tbl
            SET short_code = ?, expires_at = NULL
            WHERE short_code = ?
        ");
        $rot->bind_param("ss", $new_code, $short_code);

        if ($rot->execute()) {
            $rotated[]  = ['old' => $short_code, 'new' => $new_code];
            $short_code = $new_code;
        }
    }

    // Still valid — keep in map for Step 3
    $existing_links[$key] = $short_code;
}

// ─── 3. Build links ───────────────────────────────────────────────────────────
$links = [];

foreach ($subjects as $subject) {
    $key = $subject['subject_id'] . '|' . $subject['section'] . '|' . $subject['instructor_id'];

    if (isset($existing_links[$key])) {
        $short_code = $existing_links[$key];
    } else {
        // Ang pagsusuri kung libre pa ang code ay nasa loob na ng
        // link_generate_code() — tingnan ang includes/links.php.
        $short_code = link_generate_code($conn);

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
// Naka-cache ang listahan nang WALANG expiry; idinidikit ito sa
// bawat sagot (tingnan ang attach_link_expiry), kaya hindi kailanman
// naipupundar ang isang lumang countdown sa session.
$_SESSION[$cache_key] = ['data' => $links, 'time' => time()];

echo json_encode([
    'success' => true,
    'cached'  => false,
    'data'    => attach_link_expiry($conn, $links),
    // Para masabi ng pahina kung ilang link ang binigyan ng bagong
    // code habang wala ka — kung hindi, tahimik na magbabago ang mga
    // URL at magtataka ka kung bakit patay na ang ipinadala mo kahapon.
    'rotated' => $rotated,
]);