<?php
// ============================================================
// The Present / Absent list, injected into #attendanceModalBody by
// assets/js/view_attendance.js.
//
// Markup follows the DATA MODAL section of assets/css/modal-form.css
// (.app-chips, .app-table-wrap, .app-state) — the same vocabulary as
// the absences modal beside it. It used to be Bootstrap utilities and
// `text-white`, which did not survive light mode.
// ============================================================

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
$date         = $_GET['date']    ?? date('Y-m-d');

// Anything that is not an explicit "absent" is the present list. The
// value used to be echoed back through `ucfirst($status)` unescaped,
// so ?status= wrote straight into the page.
$status  = (($_GET['status'] ?? 'present') === 'absent') ? 'absent' : 'present';
$present = $status === 'present';

// Split "BSIT-1A" → course="BSIT", section="1A".
$parts   = explode('-', $full_section, 2);
$course  = $parts[0] ?? '';
$section = $parts[1] ?? $full_section;

if ($present) {
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
    echo '<div class="app-state">'
        . '<div class="app-state-icon is-bad"><i class="bi bi-exclamation-octagon"></i></div>'
        . '<h6>Could not load the list</h6>'
        . '<p>' . htmlspecialchars($conn->error) . '</p>'
        . '</div>';
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

// ── Stats ─────────────────────────────────────────────────
// How big the class is. A bare count says nothing on its own — 34
// present is excellent out of 36 and alarming out of 80, and the old
// tiles gave the reader no way to tell which. exports/export_pdf.php
// already leads with exactly these numbers for the same click, so the
// screen and the PDF cannot disagree.
$enrolled = 0;
if ($stmt = $conn->prepare("SELECT COUNT(*) AS n FROM students_tbl WHERE course = ? AND section = ?")) {
    $stmt->bind_param("ss", $course, $section);
    $stmt->execute();
    $enrolled = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
    $stmt->close();
}

$present_count = $present ? $total_count : max(0, $enrolled - $total_count);
$absent_count  = max(0, $enrolled - $present_count);

// Coloured by how bad it is, so the reader does not have to compare it
// against anything to know whether it needs attention. Same thresholds
// as the PDF's rate card.
$rate     = $enrolled > 0 ? round(($present_count / $enrolled) * 100, 1) : 0.0;
$rateTone = $rate >= 90 ? 'is-ok' : ($rate >= 75 ? 'is-warn' : 'is-bad');

// The roll call is the point of this list, so a time is a first-class
// column — but the stored values are a mix. Some rows are text already
// carrying seconds ("09:35:50 AM"), some are datetimes formatted by the
// query, so the column printed two different shapes down its length.
// Seconds are noise on a roll call. A value that cannot be parsed is
// shown as it was stored rather than blanked — an odd-looking time is
// still evidence; an empty cell is not.
$fmtTime = static function ($raw) {
    $raw = trim((string) $raw);
    if ($raw === '') {
        return '—';
    }
    $ts = strtotime($raw);
    return $ts === false ? $raw : date('g:i A', $ts);
};

// A filter over a handful of names is a control that cannot help. These
// lists run to 40+ though, inside a box that scrolls.
$showFilter = $total_count > 8;
?>

<?php if ($total_count > 0): ?>

    <!-- Summary. Three full-size cards used to sit here, and two of
         them ("Subject", the date) only repeated the modal header. The
         one number they carried is now shown against the class size
         that makes it mean something. -->
    <div class="app-chips">
        <span class="app-chip is-ok">
            <i class="bi bi-check2-circle" aria-hidden="true"></i>
            <?= number_format($present_count) ?> present
        </span>
        <span class="app-chip <?= $absent_count > 0 ? 'is-bad' : 'is-plain' ?>">
            <i class="bi bi-dash-circle" aria-hidden="true"></i>
            <?= number_format($absent_count) ?> absent
        </span>
        <?php if ($enrolled > 0): ?>
            <!-- Hidden when the roster has nobody in this course/section:
                 an "of 0 enrolled" chip beside 34 names is worse than no
                 chip, and the rate below it would read 0%. -->
            <span class="app-chip is-plain">
                <i class="bi bi-people" aria-hidden="true"></i>
                <?= number_format($enrolled) ?> enrolled
            </span>
            <span class="app-chip <?= $rateTone ?>">
                <i class="bi bi-graph-up-arrow" aria-hidden="true"></i>
                <?= $rate ?>% attendance
            </span>
        <?php endif; ?>
    </div>

    <?php if ($showFilter): ?>
        <div class="att-toolbar">
            <div class="app-input">
                <i class="bi bi-search" aria-hidden="true"></i>
                <label class="visually-hidden" for="attFilter">Filter this list</label>
                <input type="search" class="form-control" id="attFilter"
                       placeholder="Filter by name or student number" autocomplete="off">
            </div>
            <span class="att-shown" id="attShown"></span>
        </div>
    <?php endif; ?>

    <div class="app-table-wrap" id="attTableWrap">
        <table class="app-table">
            <thead>
                <tr>
                    <th class="app-rank">#</th>
                    <th>Student No.</th>
                    <th>Name</th>
                    <?php if ($present): ?>
                        <th class="app-time">Time In</th>
                    <?php endif; ?>
                    <!-- No Section column. It is the same value on every
                         row — it is what the query filtered on — and it
                         is already in the modal subtitle, so 40 identical
                         badges only pushed the times off a phone. -->
                </tr>
            </thead>
            <tbody>
                <?php $count = 1;
                foreach ($students as $row): ?>
                    <?php
                    // What the filter matches against, built server-side
                    // so the browser never has to re-read the rendered
                    // cells (which carry formatting the typist has not).
                    $find = strtolower($row['student_no'] . ' ' . $row['fullname']);
                    ?>
                    <tr data-find="<?= htmlspecialchars($find) ?>">
                        <td class="app-rank"><?= $count++ ?></td>
                        <td class="app-id"><?= htmlspecialchars($row['student_no']) ?></td>
                        <td><?= htmlspecialchars($row['fullname']) ?></td>
                        <?php if ($present): ?>
                            <td class="app-time"><?= htmlspecialchars($fmtTime($row['time_in'])) ?></td>
                        <?php endif; ?>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>

    <!-- Shown by view_attendance.js when the filter matches nothing. An
         empty table under a live search box reads as a broken list. -->
    <div class="app-state" id="attNoMatch" style="display: none;">
        <div class="app-state-icon"><i class="bi bi-search"></i></div>
        <h6>No match</h6>
        <p>Nobody on this list matches that name or student number.</p>
    </div>

<?php else: ?>

    <div class="app-state">
        <div class="app-state-icon"><i class="bi bi-inbox"></i></div>
        <h6>No <?= $present ? 'present' : 'absent' ?> students</h6>
        <p>
            Nothing recorded for <strong><?= htmlspecialchars($subject) ?></strong>,
            section <strong><?= htmlspecialchars($full_section) ?></strong>,
            <!-- `F j` and not `F d`: the header above is written by
                 toLocaleDateString with day:'numeric', so a zero-padded
                 day here made the same date read two ways in one
                 dialog. -->
            on <strong><?= date('F j, Y', strtotime($date) ?: time()) ?></strong>.
        </p>
    </div>

<?php endif; ?>
