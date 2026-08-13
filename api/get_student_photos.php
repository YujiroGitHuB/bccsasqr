<?php
// ============================================================
//  api/get_student_photos.php
//  Admin only — paginated + searchable student photo list.
//  Returns one page of rows so the client never loads the
//  whole students_tbl at once.
// ============================================================
session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

// Any logged-in user may view. Admins see all students; instructors are
// scoped to the students in their assigned sections (see below).
if (empty($_SESSION['user_id'])) {
    http_response_code(403);
    exit(json_encode(['success' => false, 'message' => 'Unauthorized.']));
}
requirePermissionJson('students.photos');

$user_id = (int) $_SESSION['user_id'];
$role    = $_SESSION['role'] ?? '';

// ── Inputs ────────────────────────────────────────────────
$q        = trim($_GET['q']       ?? '');
$course   = trim($_GET['course']  ?? '');
$section  = trim($_GET['section'] ?? '');
$filter   = $_GET['filter']       ?? 'all';         // all | with | without
$page     = max(1, (int)($_GET['page'] ?? 1));
$per_page = (int)($_GET['per_page'] ?? 30);
$per_page = max(1, min(60, $per_page));             // clamp 1..60
$offset   = ($page - 1) * $per_page;

// ── Build WHERE clause with bound params ──────────────────
$where  = [];
$params = [];
$types  = '';

if ($q !== '') {
    $where[]  = "(s.fullname LIKE ? OR s.student_no LIKE ?)";
    $like     = '%' . $q . '%';
    $params[] = $like;
    $params[] = $like;
    $types   .= 'ss';
}
if ($course !== '') {
    $where[]  = "s.course = ?";
    $params[] = $course;
    $types   .= 's';
}
if ($section !== '') {
    $where[]  = "s.section = ?";
    $params[] = $section;
    $types   .= 's';
}
if ($filter === 'with') {
    $where[] = "p.photo_path IS NOT NULL";
} elseif ($filter === 'without') {
    $where[] = "p.photo_path IS NULL";
}

// ── Role scope: instructors only see their assigned sections ──────────────
if ($role !== 'admin') {
    $secStmt = $conn->prepare("SELECT course, section FROM instructor_section_tbl WHERE instructor_id = ?");
    $secStmt->bind_param("i", $user_id);
    $secStmt->execute();
    $secRes = $secStmt->get_result();
    $pairs  = [];
    while ($p = $secRes->fetch_assoc()) $pairs[] = $p;
    $secStmt->close();

    if (empty($pairs)) {
        // No assigned sections → no students to show.
        exit(json_encode([
            'success' => true, 'students' => [], 'total' => 0,
            'page' => $page, 'per_page' => $per_page, 'total_pages' => 0,
        ]));
    }

    $tuples  = implode(',', array_fill(0, count($pairs), '(?,?)'));
    $where[] = "(s.course, s.section) IN ($tuples)";
    foreach ($pairs as $p) {
        $params[] = $p['course'];
        $params[] = $p['section'];
        $types   .= 'ss';
    }
}

$whereSql = $where ? ('WHERE ' . implode(' AND ', $where)) : '';

// ── Total matching count (for pagination) ─────────────────
$countSql  = "SELECT COUNT(*) FROM students_tbl s
              LEFT JOIN student_photos p ON p.s_id = s.id
              $whereSql";
$countStmt = $conn->prepare($countSql);
if ($types !== '') {
    $countStmt->bind_param($types, ...$params);
}
$countStmt->execute();
$total = (int) $countStmt->get_result()->fetch_row()[0];
$countStmt->close();

// ── Page of rows ──────────────────────────────────────────
$dataSql = "SELECT s.id, s.student_no, s.fullname, s.course, s.section,
                   p.photo_path, p.updated_at
            FROM students_tbl s
            LEFT JOIN student_photos p ON p.s_id = s.id
            $whereSql
            ORDER BY p.photo_path IS NULL DESC, s.fullname ASC
            LIMIT ? OFFSET ?";

$dataTypes  = $types . 'ii';
$dataParams = array_merge($params, [$per_page, $offset]);

$dataStmt = $conn->prepare($dataSql);
$dataStmt->bind_param($dataTypes, ...$dataParams);
$dataStmt->execute();
$result = $dataStmt->get_result();

$students = [];
while ($row = $result->fetch_assoc()) {
    $has = !empty($row['photo_path']);
    $students[] = [
        'id'            => (int) $row['id'],
        'student_no'    => $row['student_no'],
        'fullname'      => $row['fullname'],
        'course'        => $row['course'],
        'section'       => $row['section'],
        'photo_path'    => $has ? $row['photo_path'] : null,
        'has_photo'     => $has,
        'updated_label' => $row['updated_at'] ? date('M j, Y', strtotime($row['updated_at'])) : '',
    ];
}
$dataStmt->close();

echo json_encode([
    'success'     => true,
    'students'    => $students,
    'total'       => $total,
    'page'        => $page,
    'per_page'    => $per_page,
    'total_pages' => (int) ceil($total / $per_page),
]);
