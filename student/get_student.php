<?php

header('Content-Type: application/json');
header('X-Content-Type-Options: nosniff');

include "../includes/db_connect.php";

$qr_data = trim($_GET['qr_data'] ?? '');

if ($qr_data === '') {
    http_response_code(400);
    exit(json_encode(['success' => false, 'message' => 'No QR data received.']));
}

try {
    $stmt = $conn->prepare("
        SELECT
            s.id,
            s.fullname,
            s.course,
            s.section,
            p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
        LIMIT 1
    ");
    $stmt->bind_param("s", $qr_data);
    $stmt->execute();
    $student = $stmt->get_result()->fetch_assoc();
    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    exit(json_encode(['success' => false, 'message' => 'Database error.']));
}

if (!$student) {
    exit(json_encode(['success' => false, 'message' => 'Student not found.']));
}

$photo_url = null;
if (!empty($student['photo_path'])) {
    $full_path = __DIR__ . '/' . $student['photo_path'];
    if (file_exists($full_path)) {
        $photo_url = $student['photo_path'];
    }
}

exit(json_encode([
    'success' => true,
    'student' => [
        'id'         => $student['id'],
        'name'       => htmlspecialchars($student['fullname']),
        'course'     => htmlspecialchars($student['course']  ?? ''),
        'year_level' => htmlspecialchars($student['section'] ?? ''),
        'photo_url'  => $photo_url,
    ],
    'timestamp' => date('h:i A'),
    'date'      => date('F j, Y'),
]));