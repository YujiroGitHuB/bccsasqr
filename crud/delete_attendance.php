<?php
session_start();
header('Content-Type: application/json');
include("../includes/db_connect.php");
include __DIR__ . "/../includes/permissions.php";

// Require a logged-in user (instructor or admin).
if (empty($_SESSION['user_id'])) {
    echo json_encode(["success" => false, "message" => "Unauthorized"]);
    exit;
}

requirePermissionJson('attendance.delete');

if (!isset($_POST['id'])) {
    echo json_encode(["success" => false, "message" => "No ID provided"]);
    exit;
}

$id = (int) $_POST['id'];

if ($id <= 0) {
    echo json_encode(["success" => false, "message" => "Invalid record ID."]);
    exit;
}

// Scoped the same way as crud/delete_selected_attendance.php: admins may
// delete any row, instructors only the ones they recorded.
//
// This used to be a bare "WHERE id = $id" for everyone, so an
// instructor holding attendance.delete could remove another
// instructor's records by posting the id — rows they cannot even see in
// the list, since pages/attendance.php filters by user_id. The button
// being hidden was never the protection.
if (isAdmin()) {
    $stmt = $conn->prepare("DELETE FROM attendance_tbl WHERE id = ?");
    $stmt->bind_param("i", $id);
} else {
    $uid  = (int) $_SESSION['user_id'];
    $stmt = $conn->prepare("DELETE FROM attendance_tbl WHERE id = ? AND user_id = ?");
    $stmt->bind_param("ii", $id, $uid);
}

if (!$stmt->execute()) {
    echo json_encode(["success" => false, "error" => $stmt->error]);
    $stmt->close();
    exit;
}

// affected_rows separates "deleted" from "that row is not yours" — the
// old code reported success either way, so a failed attempt looked like
// a successful one.
if ($stmt->affected_rows === 0) {
    $stmt->close();
    echo json_encode([
        "success" => false,
        // An admin's query has no user_id clause, so for them the only
        // reason to match nothing is that the row is gone.
        "message" => isAdmin()
            ? "That record no longer exists."
            : "That record was not found, or it was not recorded by you."
    ]);
    exit;
}

$stmt->close();
echo json_encode(["success" => true]);
