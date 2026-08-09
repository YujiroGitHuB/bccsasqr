<?php
session_start();
include "../includes/db_connect.php";
include "../includes/auth.php";
include "../includes/permissions.php";

header('Content-Type: application/json');

// Only admins can manage users
if (!isAdmin()) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);

$user_id = $data['user_id'] ?? 0;
$new_status = $data['status'] ?? '';

// Validate inputs
if (empty($user_id) || !in_array($new_status, ['active', 'disabled'])) {
    echo json_encode(['success' => false, 'message' => 'Invalid parameters']);
    exit;
}

// Prevent disabling yourself
if ($user_id == $_SESSION['user_id']) {
    echo json_encode(['success' => false, 'message' => 'Cannot disable your own account']);
    exit;
}

// Update user status
$stmt = $conn->prepare("UPDATE users SET status = ? WHERE id = ?");
$stmt->bind_param("si", $new_status, $user_id);

if ($stmt->execute()) {
    // Get updated counts
    $active_result = $conn->query("SELECT COUNT(*) as count FROM users WHERE IFNULL(status, 'active') = 'active'");
    $disabled_result = $conn->query("SELECT COUNT(*) as count FROM users WHERE status = 'disabled'");
    $total_result = $conn->query("SELECT COUNT(*) as count FROM users");
    
    echo json_encode([
        'success' => true,
        'message' => 'User status updated successfully',
        'active_count' => $active_result->fetch_assoc()['count'],
        'disabled_count' => $disabled_result->fetch_assoc()['count'],
        'total_count' => $total_result->fetch_assoc()['count']
    ]);
} else {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $conn->error]);
}

$stmt->close();
$conn->close();
?>