<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

// Check if user is admin
if (!isAdmin()) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized access']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['subject_id'])) {
    $subjectId = (int)$_POST['subject_id']; // Cast to integer
    
    if ($subjectId <= 0) {
        echo json_encode(['success' => false, 'message' => 'Invalid subject ID']);
        exit;
    }
    
    // Check if subject exists using prepared statement
    $checkStmt = $conn->prepare("SELECT id FROM subjects_tbl WHERE id = ?");
    $checkStmt->bind_param("i", $subjectId);
    $checkStmt->execute();
    $checkStmt->store_result();
    
    if ($checkStmt->num_rows == 0) {
        $checkStmt->close();
        echo json_encode(['success' => false, 'message' => 'Subject not found']);
        exit;
    }
    $checkStmt->close();
    
    // Start transaction
    $conn->begin_transaction();
    
    try {
        // Delete from child table first
        $stmt1 = $conn->prepare("DELETE FROM subject_instructors_tbl WHERE subject_id = ?");
        $stmt1->bind_param("i", $subjectId);
        $success1 = $stmt1->execute();
        $stmt1->close();
        
        // Delete from parent table
        $stmt2 = $conn->prepare("DELETE FROM subjects_tbl WHERE id = ?");
        $stmt2->bind_param("i", $subjectId);
        $success2 = $stmt2->execute();
        $stmt2->close();
        
        if ($success1 && $success2) {
            $conn->commit();
            echo json_encode(['success' => true, 'message' => 'Subject deleted successfully']);
        } else {
            $conn->rollback();
            echo json_encode(['success' => false, 'message' => 'Failed to delete subject']);
        }
        
    } catch (Exception $e) {
        $conn->rollback();
        echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
    }
    
} else {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
}
?>