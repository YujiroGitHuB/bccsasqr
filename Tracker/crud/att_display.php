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
        //
        // LEFT JOIN, not INNER: the photo is optional here. A student
        // with no row in student_photos still has an attendance record
        // to look at, and the identity card falls back to initials.
        // Same join the dashboard, the scanner and the generator use.
        $check_student = $conn->prepare("
            SELECT s.student_no, s.fullname, s.course, s.section,
                   p.photo_path
            FROM students_tbl s
            LEFT JOIN student_photos p ON p.s_id = s.id
            WHERE s.student_no = ?
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

        // Initials for the name tile — now the FALLBACK behind the
        // photo rather than the only thing shown, for the students who
        // have not uploaded one. An empty tile says nothing either.
        $trk_initials = function ($name) {
            // fullname is formatted "Surname, First M." here, so the
            // first two words are taken rather than the first and last
            // — the last one is the middle initial.
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

        // The identity tile, rendered by BOTH result states below (the
        // one with a table under it and the "no attendance yet" one).
        // One closure rather than two copies of the markup, so the
        // photo cannot end up on only one of them.
        //
        // The <img> sits ON TOP of the initials rather than replacing
        // them, and `onerror` removes it — student_photos can outlive
        // the file on disk, and a stale row should degrade to the
        // letters instead of a broken-image icon. Same trick as
        // components/recent_activity_rows.php.
        //
        // photo_path is stored relative to the app root; the tracker is
        // one folder down, hence "../".
        $trk_avatar = function ($student) use ($trk_initials) {
            $letters = htmlspecialchars($trk_initials($student['fullname']));
            $name    = htmlspecialchars((string) $student['fullname']);
            $html    = '<div class="trk-avatar">';
            if (!empty($student['photo_path'])) {
                $html .= '<img src="../' . htmlspecialchars($student['photo_path']) . '"'
                    . ' alt="Photo of ' . $name . '"'
                    . ' loading="lazy" decoding="async"'
                    . ' onerror="this.remove()">';
            }
            return $html . $letters . '</div>';
        };

        // Last attendance. The query sorts by subject before date, so
        // the first row is not the most recent overall — the maximum
        // has to be found.
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
                <!-- Who was found. The name is what the eye looks for to
                     confirm the right person; the rest are supporting
                     chips. -->
                <div class="trk-identity">
                    <?= $trk_avatar($student_info) ?>
                    <div class="trk-identity-text">
                        <h2><?= htmlspecialchars($student_info['fullname']) ?></h2>
                        <div class="trk-meta">
                            <span><i class="bi bi-person-badge"></i> <?= htmlspecialchars($student_info['student_no']) ?></span>
                            <span><i class="bi bi-mortarboard"></i> <?= htmlspecialchars($student_info['course']) ?></span>
                            <span><i class="bi bi-people"></i> <?= htmlspecialchars($student_info['section']) ?></span>
                        </div>
                    </div>
                </div>

                <!-- The summary. The subject count and the last
                     attendance were already in the table before, but you
                     had to count them yourself. -->
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
                    <?= $trk_avatar($student_info) ?>
                    <div class="trk-identity-text">
                        <h2><?= htmlspecialchars($student_info['fullname']) ?></h2>
                        <div class="trk-meta">
                            <span><i class="bi bi-person-badge"></i> <?= htmlspecialchars($student_info['student_no']) ?></span>
                        </div>
                    </div>
                </div>

                <!-- Only the name used to appear here, which looked like
                     a truncated result. It now says why there is no
                     table below. -->
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