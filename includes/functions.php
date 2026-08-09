<?php
function assignStudentToInstructor($conn, $student_id, $instructor_id) {
    // Check if already assigned
    $check = $conn->prepare("SELECT * FROM instructor_student_tbl WHERE student_id = ? AND instructor_id = ?");
    $check->bind_param("ii", $student_id, $instructor_id);
    $check->execute();
    $result = $check->get_result();

    if($result->num_rows > 0){
        return ['success' => false, 'message' => 'Student is already assigned to this instructor.'];
    }

    // Assign
    $insert = $conn->prepare("INSERT INTO instructor_student_tbl (student_id, instructor_id) VALUES (?, ?)");
    $insert->bind_param("ii", $student_id, $instructor_id);

    if($insert->execute()){
        return ['success' => true, 'message' => 'Student assigned successfully!'];
    } else {
        return ['success' => false, 'message' => 'Error assigning student: ' . $conn->error];
    }
}
?>