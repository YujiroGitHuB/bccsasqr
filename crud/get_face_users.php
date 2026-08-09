<?php
// ========================================
// GET FACE USERS API
// Returns all users with face recognition enabled
// ========================================

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors in JSON response

try {
    include __DIR__ . '/../includes/db_connect.php';
    
    // Check if connection exists
    if (!isset($conn)) {
        throw new Exception('Database connection failed');
    }
    
    // Query to get all users with face recognition enabled
    $stmt = $conn->prepare("
        SELECT id, name, email, face_descriptor 
        FROM users 
        WHERE face_enabled = 1 
        AND face_descriptor IS NOT NULL 
        AND face_descriptor != ''
    ");
    
    if (!$stmt) {
        throw new Exception('Prepare statement failed: ' . $conn->error);
    }
    
    if (!$stmt->execute()) {
        throw new Exception('Execute failed: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    if (!$result) {
        throw new Exception('Get result failed: ' . $stmt->error);
    }
    
    $users = [];
    while ($row = $result->fetch_assoc()) {
        // Validate that face_descriptor is valid JSON
        $descriptor = $row['face_descriptor'];
        if (!empty($descriptor)) {
            // Test if it's valid JSON
            $testDecode = json_decode($descriptor);
            if (json_last_error() === JSON_ERROR_NONE) {
                $users[] = [
                    'id' => (int)$row['id'],
                    'name' => $row['name'],
                    'email' => $row['email'],
                    'face_descriptor' => $descriptor
                ];
            }
        }
    }
    
    $stmt->close();
    $conn->close();
    
    // Return success response
    echo json_encode([
        'success' => true,
        'users' => $users,
        'count' => count($users),
        'message' => count($users) > 0 ? 'Users loaded successfully' : 'No users with face recognition found'
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    // Log the error
    error_log('Face users API error: ' . $e->getMessage());
    
    // Return error response
    echo json_encode([
        'success' => false,
        'message' => 'Error fetching users: ' . $e->getMessage(),
        'users' => [],
        'count' => 0
    ], JSON_PRETTY_PRINT);
}
?>