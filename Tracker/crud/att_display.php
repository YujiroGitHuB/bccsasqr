<?php
$attendance_records = [];
$student_info = null;
$total_attendance = 0;
$search_performed = false;
$status = '';
$subjects_summary = []; // NEW: For grouping by subject

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['student_no'])) {
    $student_no = trim($_POST['student_no']);

    try {
        // STEP 1: Check if student exists
        $check_student = $conn->prepare("
            SELECT student_no, fullname, course, section 
            FROM students_tbl 
            WHERE student_no = ?
        ");
        $check_student->bind_param("s", $student_no);
        $check_student->execute();
        $student_result = $check_student->get_result();

        if ($student_result->num_rows > 0) {
            $student_info = $student_result->fetch_assoc();

            // STEP 2: Get attendance records WITH subject grouping
            $stmt = $conn->prepare("
                SELECT id, date, student_no, name, course, section, 
                       subject, instructor, time_in 
                FROM attendance_tbl 
                WHERE student_no = ? 
                ORDER BY subject, date DESC
            ");
            $stmt->bind_param("s", $student_no);
            $stmt->execute();
            $result = $stmt->get_result();
            $attendance_records = $result->fetch_all(MYSQLI_ASSOC);
            $total_attendance = count($attendance_records);

            // NEW: Group attendance by subject
            foreach ($attendance_records as $record) {
                $subject = $record['subject'] ?? 'No Subject';
                if (!isset($subjects_summary[$subject])) {
                    $subjects_summary[$subject] = [
                        'count' => 0,
                        'instructor' => $record['instructor'] ?? 'N/A',
                        'records' => []
                    ];
                }
                $subjects_summary[$subject]['count']++;
                $subjects_summary[$subject]['records'][] = $record;
            }

            if ($total_attendance > 0) {
                $status = 'success';
            } else {
                $status = 'no-attendance';
            }

            $stmt->close();
        } else {
            $status = 'not-found';
        }

        $check_student->close();
        $search_performed = true;
    } catch (Exception $e) {
        error_log(
            date("Y-m-d H:i:s") . " | Attendance Search Error: " . $e->getMessage() . PHP_EOL,
            3,
            __DIR__ . "/attendance_search_error.log"
        );
        $search_performed = true;
        $status = 'error';
    }

    if ($search_performed && isset($_POST['student_no'])) {
?>
        <div class="results-container" data-status="<?= $status ?>">
            <?php if ($status === 'success'): ?>
                <!-- Student Info -->
                <div class="student-info">
                    <div class="info-row">
                        <span class="info-label">Student Number:</span>
                        <span class="info-value"><?= htmlspecialchars($student_info['student_no']) ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Name:</span>
                        <span class="info-value"><?= htmlspecialchars($student_info['fullname']) ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Course:</span>
                        <span class="info-value"><?= htmlspecialchars($student_info['course']) ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Section:</span>
                        <span class="info-value"><?= htmlspecialchars($student_info['section']) ?></span>
                    </div>
                </div>

                <!-- Total Attendance -->
                <div class="total-attendance">
                    <h2>Total Attendance</h2>
                    <div class="total-count"><?= $total_attendance ?></div>
                    <p>days present</p>
                </div>

                <!-- NEW: Attendance Per Subject -->
                <div class="subjects-container">
                    <h2>Attendance by Subject</h2>
                    <?php foreach ($subjects_summary as $subject => $data): ?>
                        <div class="subject-card">
                            <div class="subject-header">
                                <h3><?= htmlspecialchars($subject) ?></h3>
                                <span class="subject-count"><?= $data['count'] ?> days</span>
                            </div>
                            <p class="instructor-name">Instructor: <?= htmlspecialchars($data['instructor']) ?></p>
                            
                            <table class="attendance-table">
                                <thead>
                                    <tr>
                                        <th>#</th>
                                        <th>Date</th>
                                        <th>Time In</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($data['records'] as $index => $record): ?>
                                        <tr>
                                            <td><?= $index + 1 ?></td>
                                            <td><?= date('F d, Y', strtotime($record['date'])) ?></td>
                                            <td><?= htmlspecialchars($record['time_in']) ?></td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php endforeach; ?>
                </div>

            <?php elseif ($status === 'no-attendance'): ?>
                <!-- Same as before -->
                <div class="student-info">
                    <div class="info-row">
                        <span class="info-label">Student Number:</span>
                        <span class="info-value"><?= htmlspecialchars($student_info['student_no']) ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Name:</span>
                        <span class="info-value"><?= htmlspecialchars($student_info['fullname']) ?></span>
                    </div>
                </div>
            <?php endif; ?>
        </div>
<?php
        exit;
    }
}
?>