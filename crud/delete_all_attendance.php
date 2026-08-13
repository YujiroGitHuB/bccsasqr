<?php
session_start();
include("../includes/db_connect.php");
include __DIR__ . "/../includes/permissions.php";

if (!isset($_SESSION['user_id'])) {
    echo json_encode(["success" => false, "message" => "Unauthorized access"]);
    exit;
}

// "Delete All" has only ever been offered to admins in the UI
// (pages/attendance.php), but the endpoint accepted any signed-in
// user — an instructor could wipe the whole table by calling it
// directly. It is now admin-only, matching the button.
if (!isAdmin()) {
    echo json_encode(["success" => false, "message" => "Only an administrator can delete all attendance records."]);
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