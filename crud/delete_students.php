<?php
session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

if (!isAdmin()) {
    echo json_encode(["status" => "unauthorized"]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = intval($_POST['id']);

    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM students_tbl WHERE id = ?");
        $stmt->bind_param("i", $id);

        if ($stmt->execute()) {
            echo json_encode(["status" => "success"]);
        } else {
            echo json_encode(["status" => "error", "msg" => $stmt->error]);
        }

        $stmt->close();
    } else {
        echo json_encode(["status" => "invalid"]);
    }
}
?>
