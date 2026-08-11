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

        // Mga unang titik para sa tile ng pangalan. Walang larawan
        // ang pahinang ito ng estudyante, at ang isang blangkong
        // bilog ay wala ring sinasabi.
        $trk_initials = function ($name) {
            // "Apelyido, Pangalan G." ang pormat ng fullname dito, kaya
            // ang unang dalawang salita ang kinukuha at hindi ang una
            // at huli — ang huli ay ang inisyal ng gitnang pangalan.
            $parts = preg_split('/[\s,]+/', trim((string) $name), -1, PREG_SPLIT_NO_EMPTY);
            if (!$parts) {
                return '?';
            }
            $letters = mb_substr($parts[0], 0, 1);
            if (isset($parts[1])) {
                $letters .= mb_substr($parts[1], 0, 1);
            }
            return mb_strtoupper($letters);
        };

        // Huling pagdalo. Naka-uri ang query ayon sa subject bago
        // ang petsa, kaya hindi ang unang hanay ang pinakabago sa
        // buong talaan — kailangang hanapin ang pinakamalaki.
        $latest_date = null;
        foreach ($attendance_records as $record) {
            $ts = strtotime((string) $record['date']);
            if ($ts && (!$latest_date || $ts > $latest_date)) {
                $latest_date = $ts;
            }
        }
?>
        <div class="results-container" data-status="<?= $status ?>">
            <?php if ($status === 'success'): ?>
                <!-- Sino ang natagpuan. Ang pangalan ang hinahanap ng
                     mata para makumpirmang tama ang tao; ang iba ay
                     mga chip na sumusuporta lang. -->
                <div class="trk-identity">
                    <div class="trk-avatar"><?= htmlspecialchars($trk_initials($student_info['fullname'])) ?></div>
                    <div class="trk-identity-text">
                        <h2><?= htmlspecialchars($student_info['fullname']) ?></h2>
                        <div class="trk-meta">
                            <span><i class="bi bi-person-badge"></i> <?= htmlspecialchars($student_info['student_no']) ?></span>
                            <span><i class="bi bi-mortarboard"></i> <?= htmlspecialchars($student_info['course']) ?></span>
                            <span><i class="bi bi-people"></i> <?= htmlspecialchars($student_info['section']) ?></span>
                        </div>
                    </div>
                </div>

                <!-- Ang buod. Ang bilang ng subject at ang huling
                     pagdalo ay nasa talaan na noon pero kailangan mong
                     bilangin sila mismo. -->
                <div class="trk-stats">
                    <div class="trk-stat is-primary">
                        <div class="trk-stat-label"><i class="bi bi-check2-circle"></i> Days present</div>
                        <div class="trk-stat-value"><?= (int) $total_attendance ?></div>
                    </div>
                    <div class="trk-stat">
                        <div class="trk-stat-label"><i class="bi bi-journal-text"></i> Subjects</div>
                        <div class="trk-stat-value"><?= count($subjects_summary) ?></div>
                    </div>
                    <div class="trk-stat">
                        <div class="trk-stat-label"><i class="bi bi-calendar-event"></i> Last attended</div>
                        <div class="trk-stat-value is-text"><?= $latest_date ? date('M d, Y', $latest_date) : '—' ?></div>
                    </div>
                </div>

                <!-- Attendance Per Subject -->
                <div class="subjects-container">
                    <?php foreach ($subjects_summary as $subject => $data): ?>
                        <div class="subject-card">
                            <div class="subject-header">
                                <div class="subject-heading">
                                    <h3><?= htmlspecialchars($subject) ?></h3>
                                    <p class="instructor-name"><i class="bi bi-person"></i> <?= htmlspecialchars($data['instructor']) ?></p>
                                </div>
                                <span class="subject-count">
                                    <i class="bi bi-check2"></i>
                                    <?= $data['count'] ?> <?= $data['count'] === 1 ? 'day' : 'days' ?>
                                </span>
                            </div>

                            <div class="table-scroll">
                                <table class="attendance-table">
                                    <thead>
                                        <tr>
                                            <th class="col-num">#</th>
                                            <th>Date</th>
                                            <th class="col-time">Time in</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach ($data['records'] as $index => $record): ?>
                                            <?php $ts = strtotime((string) $record['date']); ?>
                                            <tr>
                                                <td class="col-num"><?= $index + 1 ?></td>
                                                <td class="cell-date">
                                                    <?= $ts ? date('M d, Y', $ts) : htmlspecialchars($record['date']) ?>
                                                    <?php if ($ts): ?>
                                                        <span class="cell-day"><?= date('l', $ts) ?></span>
                                                    <?php endif; ?>
                                                </td>
                                                <td class="cell-time"><?= htmlspecialchars($record['time_in']) ?></td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>

            <?php elseif ($status === 'no-attendance'): ?>
                <div class="trk-identity">
                    <div class="trk-avatar"><?= htmlspecialchars($trk_initials($student_info['fullname'])) ?></div>
                    <div class="trk-identity-text">
                        <h2><?= htmlspecialchars($student_info['fullname']) ?></h2>
                        <div class="trk-meta">
                            <span><i class="bi bi-person-badge"></i> <?= htmlspecialchars($student_info['student_no']) ?></span>
                        </div>
                    </div>
                </div>

                <!-- Ang pangalan lang ang lumalabas dati dito, na
                     mukhang putol na resulta. Sinasabi na ngayon kung
                     bakit walang talahanayan sa ilalim. -->
                <div class="no-results">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 7V3m8 4V3M3 11h18M5 5h14a2 2 0 012 2v12a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2z"></path>
                    </svg>
                    <h3>No attendance yet</h3>
                    <p>This record exists, but no scan has been logged for it. Your first scan will show up here.</p>
                </div>
            <?php endif; ?>
        </div>
<?php
        exit;
    }
}
?>