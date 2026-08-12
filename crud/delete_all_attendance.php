<?php
session_start();
include("../includes/db_connect.php");

if (!isset($_SESSION['user_id'])) {
    echo json_encode(["success" => false, "message" => "Unauthorized access"]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    
    // Delete everything, no WHERE filter
    $sql = "DELETE FROM attendance_tbl";
    $stmt = $conn->prepare($sql);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "All attendance records have been deleted.",
            "rows_deleted" => $stmt->affected_rows
        ]);
    } else {
        echo json_encode(["success" => false, "error" => $stmt->error]);
    }

    $stmt->close();
} else {
    echo json_encode(["success" => false, "message" => "Invalid request"]);
}

$conn->close();
?>