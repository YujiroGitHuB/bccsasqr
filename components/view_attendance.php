<?php
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");
header("Expires: 0");

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/auth.php";

date_default_timezone_set('Asia/Manila');

$subject      = $_GET['subject'] ?? '';
$full_section = $_GET['section'] ?? ''; // e.g. "BSIT-1A"
$status       = $_GET['status']  ?? 'present';
$date         = $_GET['date']    ?? date('Y-m-d');

// ✅ FIXED: split "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = $parts[0] ?? '';
$section = $parts[1] ?? $full_section;

if ($status === 'present') {
    $query = "
        SELECT
            s.student_no,
            s.fullname,
            s.course,
            s.section,
            MIN(
                CASE
                    WHEN a.time_in LIKE '%AM%' OR a.time_in LIKE '%PM%' THEN a.time_in
                    ELSE DATE_FORMAT(a.time_in, '%h:%i %p')
                END
            ) AS time_in
        FROM students_tbl s
        INNER JOIN attendance_tbl a ON s.student_no = a.student_no
        WHERE s.course   = ?
          AND s.section  = ?
          AND a.subject  = ?
          AND DATE(a.date) = ?
        GROUP BY s.student_no, s.fullname, s.course, s.section
        ORDER BY s.fullname
    ";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("ssss", $course, $section, $subject, $date);
} else {
    // Absent — in section but NOT in attendance for this subject+date
    $query = "
        SELECT s.student_no, s.fullname, s.course, s.section
        FROM students_tbl s
        WHERE s.course  = ?
          AND s.section = ?
          AND s.student_no NOT IN (
              SELECT DISTINCT a.student_no
              FROM attendance_tbl a
              WHERE a.subject    = ?
                AND a.section   = ?
                AND DATE(a.date) = ?
          )
        ORDER BY s.fullname
    ";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("sssss", $course, $section, $subject, $section, $date);
}

if (!$stmt) {
    echo '<div class="alert alert-danger">Database error: ' . htmlspecialchars($conn->error) . '</div>';
    exit;
}

$stmt->execute();
$result = $stmt->get_result();

$students = [];
while ($row = $result->fetch_assoc()) {
    $students[] = $row;
}
$total_count = count($students);
$stmt->close();
?>

<?php if ($total_count > 0): ?>
    <!-- Summary Cards -->
    <div class="row g-3 mb-4">
        <div class="col-md-4">
            <div class="card bg-primary bg-opacity-10 border-0 rounded-4">
                <div class="card-body text-center">
                    <i class="bi bi-people-fill text-primary fs-2"></i>
                    <h3 class="text-white fw-bold mt-2 mb-0"><?= $total_count ?></h3>
                    <small class="text-white-50">Total <?= ucfirst($status) ?></small>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="card bg-info bg-opacity-10 border-0 rounded-4">
                <div class="card-body text-center">
                    <i class="bi bi-book-fill text-info fs-2"></i>
                    <h3 class="text-white fw-bold mt-2 mb-0"><?= htmlspecialchars($subject) ?></h3>
                    <small class="text-white-50">Subject</small>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="card bg-warning bg-opacity-10 border-0 rounded-4">
                <div class="card-body text-center">
                    <i class="bi bi-calendar-check text-warning fs-2"></i>
                    <h3 class="text-white fw-bold mt-2 mb-0"><?= date('d', strtotime($date)) ?></h3>
                    <small class="text-white-50">
                        <?= date('M Y', strtotime($date)) ?> — <?= htmlspecialchars($full_section) ?>
                    </small>
                </div>
            </div>
        </div>
    </div>

    <!-- Students Table -->
    <div class="table-responsive">
        <table class="table table-modern text-white">
            <thead>
                <tr class="text-white-50">
                    <th class="fw-semibold">#</th>
                    <th class="fw-semibold">Student No</th>
                    <th class="fw-semibold">Name</th>
                    <th class="fw-semibold">Section</th>
                    <?php if ($status === 'present'): ?>
                        <th class="fw-semibold">Time In</th>
                    <?php endif; ?>
                </tr>
            </thead>
            <tbody>
                <?php $count = 1; foreach ($students as $row): ?>
                    <tr>
                        <td><span class="badge bg-primary rounded-pill"><?= $count++ ?></span></td>
                        <td class="fw-semibold"><?= htmlspecialchars($row['student_no']) ?></td>
                        <td>
                            <i class="bi bi-person-circle text-primary me-2"></i>
                            <?= htmlspecialchars($row['fullname']) ?>
                        </td>
                        <td>
                            <span class="badge badge-modern bg-info">
                                <?= htmlspecialchars($row['course'] . '-' . $row['section']) ?>
                            </span>
                        </td>
                        <?php if ($status === 'present'): ?>
                            <td>
                                <i class="bi bi-clock text-success me-2"></i>
                                <?= htmlspecialchars($row['time_in']) ?>
                            </td>
                        <?php endif; ?>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>

<?php else: ?>
    <div class="text-center py-5">
        <div class="mb-4">
            <i class="bi bi-inbox fs-1 text-white-50"></i>
        </div>
        <h5 class="text-white mb-2">No <?= ucfirst($status) ?> Students</h5>
        <p class="text-white-50">
            No <?= $status ?> students found for
            <strong><?= htmlspecialchars($subject) ?></strong> —
            Section <strong><?= htmlspecialchars($full_section) ?></strong>
            on <strong><?= date('F d, Y', strtotime($date)) ?></strong>.
        </p>
    </div>
<?php endif; ?>