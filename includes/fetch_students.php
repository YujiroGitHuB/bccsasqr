<?php
include("db_connect.php");

if (isset($_GET['studentNo'])) {
    $studentNo = trim($_GET['studentNo']);

    $sql = "SELECT fullname, course, section FROM students_tbl WHERE student_no = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $studentNo);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        echo json_encode($result->fetch_assoc());
    } else {
        echo json_encode(["error" => "Student not found"]);
    }
}
?>

