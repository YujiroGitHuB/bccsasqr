<?php
session_start();
include "../includes/db_connect.php";

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method']);
    exit;
}

// Get assignment IDs array
$assignment_ids_json = isset($_POST['assignment_ids']) ? $_POST['assignment_ids'] : '';
$assignment_ids = json_decode($assignment_ids_json, true);

// Validate input
if (empty($assignment_ids) || !is_array($assignment_ids)) {
    echo json_encode(['success' => false, 'message' => 'No assignments selected']);
    exit;
}

// Sanitize IDs
$assignment_ids = array_map('intval', $assignment_ids);
$assignment_ids = array_filter($assignment_ids, function($id) {
    return $id > 0;
});

if (empty($assignment_ids)) {
    echo json_encode(['success' => false, 'message' => 'Invalid assignment IDs']);
    exit;
}

// Begin transaction
mysqli_begin_transaction($conn);

try {
    $deleted_count = 0;
    
    foreach ($assignment_ids as $id) {
        $deleteQuery = "DELETE FROM instructor_section_tbl WHERE id = $id";
        
        if (mysqli_query($conn, $deleteQuery)) {
            $deleted_count++;
        }
    }
    
    // Commit transaction
    mysqli_commit($conn);
    
    $message = "Successfully deleted $deleted_count " . ($deleted_count == 1 ? 'assignment' : 'assignments');
    
    echo json_encode([
        'success' => true,
        'message' => $message,
        'deleted_count' => $deleted_count
    ]);
    
} catch (Exception $e) {
    mysqli_rollback($conn);
    echo json_encode([
        'success' => false,
        'message' => 'An error occurred: ' . $e->getMessage()
    ]);
}

mysqli_close($conn);
?>