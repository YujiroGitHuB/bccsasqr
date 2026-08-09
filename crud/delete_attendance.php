<?php
session_start();
header('Content-Type: application/json');
include("../includes/db_connect.php");

// Require a logged-in user (instructor or admin).
if (empty($_SESSION['user_id'])) {
    echo json_encode(["success" => false, "message" => "Unauthorized"]);
    exit;
}

if (isset($_POST['id'])) {
    $id = intval($_POST['id']);

    $sql = "DELETE FROM attendance_tbl WHERE id = $id";
    if ($conn->query($sql)) {
        echo json_encode(["success" => true]);
    } else {
        echo json_encode(["success" => false, "error" => $conn->error]);
    }
} else {
    echo json_encode(["success" => false, "message" => "No ID provided"]);
}
?>
