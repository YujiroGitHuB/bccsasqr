<?php
session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";

$user_id = (int)$_SESSION['user_id'];

// Helper: strip course prefix from section (e.g. "BSIT-2A" → "2A", "2A" → "2A")
function cleanSection($section) {
    return preg_replace('/^[A-Z]+-/', '', $section);
}
?>
<!doctype html>
<html lang="en" data-bs-theme="dark">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content" id="content">
        <?php include("../components/topBar.php"); ?>

        <h2>Attendance</h2>

        <ul class="nav nav-tabs" id="attendanceTabs" role="tablist">
            <li class="nav-item" role="presentation">
                <button class="nav-link active" id="records-tab" data-bs-toggle="tab"
                    data-bs-target="#records" type="button" role="tab">
                    <i class="bi bi-table"></i> Records
                </button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="summary-tab" data-bs-toggle="tab"
                    data-bs-target="#summary" type="button" role="tab">
                    <i class="bi bi-bar-chart"></i> Summary
                </button>
            </li>
        </ul>

        <?php include __DIR__ . "/../components/upload_attendance_modal.php"; ?>

        <div class="tab-content mt-3" id="attendanceTabsContent">

            <!-- ══ RECORDS TAB ══════════════════════════════════════ -->
            <div class="tab-pane fade show active" id="records" role="tabpanel">
                <div class="card p-3">
                    <h5 class="mb-3 d-flex justify-content-between align-items-center">
                        <span>Attendance Records</span>
                        <div class="d-flex gap-2">
                            <button id="deleteSelected" class="btn btn-danger btn-icon" disabled>
                                <i class="bi bi-trash"></i>
                                <span class="btn-text">Delete Selected</span>
                            </button>
                            <?php if (isAdmin()): ?>
                                <button id="deleteAll" class="btn btn-danger btn-icon">
                                    <i class="bi bi-trash"></i>
                                    <span class="btn-text">Delete All</span>
                                </button>
                            <?php endif; ?>
                        </div>
                    </h5>

                    <div class="card">
                        <div id="tableLoader" class="text-center py-5">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                            <p class="mt-2 text-muted">Please wait, loading data...</p>
                        </div>

                        <?php
                        if (isAdmin()) {
                            $result = $conn->query("
                                SELECT id, date, student_no, name, course, section, time_in, subject
                                FROM attendance_tbl
                                ORDER BY date DESC
                            ");
                        } else {
                            $stmt = $conn->prepare("
                                SELECT id, date, student_no, name, course, section, time_in, subject
                                FROM attendance_tbl
                                WHERE user_id = ?
                                ORDER BY date DESC
                            ");
                            $stmt->bind_param("i", $user_id);
                            $stmt->execute();
                            $result = $stmt->get_result();
                        }
                        ?>

                        <div id="tableContainer" style="display:none;">
                            <div class="d-flex align-items-end gap-3 mb-3 flex-wrap">
                                <div>
                                    <label for="filterDate" class="form-label mb-1">Filter by Date:</label>
                                    <input type="date" id="filterDate" class="form-control form-control-sm">
                                </div>
                                <div>
                                    <label for="filterSection" class="form-label mb-1">Filter by Section:</label>
                                    <select id="filterSection" class="form-select form-select-sm">
                                        <option value="">All Sections</option>
                                        <?php
                                        if (isAdmin()) {
                                            $secQ = $conn->query("
                                                SELECT DISTINCT course, section
                                                FROM attendance_tbl
                                                ORDER BY course, section
                                            ");
                                        } else {
                                            $secStmt = $conn->prepare("
                                                SELECT DISTINCT course, section
                                                FROM attendance_tbl
                                                WHERE user_id = ?
                                                ORDER BY course, section
                                            ");
                                            $secStmt->bind_param("i", $user_id);
                                            $secStmt->execute();
                                            $secQ = $secStmt->get_result();
                                        }
                                        while ($sec = $secQ->fetch_assoc()) {
                                            $cleanSec = cleanSection($sec['section']);
                                            $full = htmlspecialchars($cleanSec);
                                            echo "<option value='{$full}'>{$full}</option>";
                                        }
                                        ?>
                                    </select>
                                </div>
                                <button id="resetFilters" class="btn btn-secondary btn-sm">
                                    <i class="bi bi-recycle"></i> Reset Filters
                                </button>
                            </div>

                            <div class="table-responsive">
                                <table id="example" class="table table-striped" style="width:100%;">
                                    <thead>
                                        <tr>
                                            <th class="text-center"><input type="checkbox" id="selectAllAttendance" title="Select all"></th>
                                            <th>No.</th>
                                            <th>Date</th>
                                            <th>Student Number</th>
                                            <th>Full Name</th>
                                            <th>Course</th>
                                            <th>Section</th>
                                            <th>Time In</th>
                                            <th>Subject</th>
                                            <th>Action</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php $counter = 1; while ($row = $result->fetch_assoc()): ?>
                                            <?php $cleanSec = cleanSection($row['section']); ?>
                                            <tr id="row-<?= $row['id'] ?>">
                                                <td class="text-center"><input type="checkbox" class="rowCheck" value="<?= $row['id'] ?>"></td>
                                                <td><?= $counter++ ?></td>
                                                <td><?= htmlspecialchars($row['date']) ?></td>
                                                <td><?= htmlspecialchars($row['student_no']) ?></td>
                                                <td><?= htmlspecialchars($row['name']) ?></td>
                                                <td><?= htmlspecialchars($row['course']) ?></td>
                                                <td><?= htmlspecialchars($cleanSec) ?></td>
                                                <td><?= htmlspecialchars($row['time_in']) ?></td>
                                                <td><?= htmlspecialchars($row['subject']) ?></td>
                                                <td>
                                                    <button class="btn-delete" data-id="<?= $row['id'] ?>">
                                                        <i class="bi bi-trash"></i>
                                                    </button>
                                                </td>
                                            </tr>
                                        <?php endwhile; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ══ SUMMARY TAB ══════════════════════════════════════ -->
            <div class="tab-pane fade" id="summary" role="tabpanel">
                <div class="card p-3">
                    <h5 class="mb-3">Attendance Summary</h5>

                    <?php
                    $summaryData = [];

                    if (isAdmin()) {
                        $sqlSummary = "
                            SELECT s.student_no, s.fullname, s.course, s.section,
                                   a.subject,
                                   COUNT(a.id) AS total_attendance
                            FROM students_tbl s
                            LEFT JOIN attendance_tbl a ON s.student_no = a.student_no
                            GROUP BY s.student_no, s.fullname, s.course, s.section, a.subject
                            ORDER BY s.fullname ASC, a.subject ASC
                        ";
                        $summaryResult = $conn->query($sqlSummary);
                        if ($summaryResult) {
                            while ($row = $summaryResult->fetch_assoc()) {
                                $summaryData[] = $row;
                            }
                        }
                    } else {
                        $secStmt = $conn->prepare("
                            SELECT course, section
                            FROM instructor_section_tbl
                            WHERE instructor_id = ?
                        ");
                        $secStmt->bind_param("i", $user_id);
                        $secStmt->execute();
                        $secResult = $secStmt->get_result();

                        $assigned = [];
                        while ($row = $secResult->fetch_assoc()) {
                            $assigned[] = $row;
                        }

                        if (!empty($assigned)) {
                            $conditions = implode(' OR ', array_map(
                                fn($s) => "(s.course = '" . $conn->real_escape_string($s['course']) . "'"
                                        . " AND s.section = '" . $conn->real_escape_string($s['section']) . "')",
                                $assigned
                            ));

                            $sqlSummary = "
                                SELECT s.student_no, s.fullname, s.course, s.section,
                                       a.subject,
                                       COUNT(a.id) AS total_attendance
                                FROM students_tbl s
                                LEFT JOIN attendance_tbl a
                                    ON s.student_no = a.student_no
                                    AND a.user_id = $user_id
                                WHERE $conditions
                                GROUP BY s.student_no, s.fullname, s.course, s.section, a.subject
                                ORDER BY s.fullname ASC, a.subject ASC
                            ";
                            $summaryResult = $conn->query($sqlSummary);
                            if ($summaryResult) {
                                while ($row = $summaryResult->fetch_assoc()) {
                                    $summaryData[] = $row;
                                }
                            }
                        }
                    }

                    // Build filter options
                    $courses        = [];
                    $sectionsFilter = [];
                    $subjects       = [];
                    foreach ($summaryData as $row) {
                        $cleanSec = cleanSection($row['section']);
                        $full_sec = $cleanSec;
                        if (!in_array($row['course'], $courses))   $courses[]        = $row['course'];
                        if (!in_array($full_sec, $sectionsFilter)) $sectionsFilter[] = $full_sec;
                        if ($row['subject'] && !in_array($row['subject'], $subjects)) $subjects[] = $row['subject'];
                    }
                    ?>

                    <?php if (!empty($summaryData)): ?>
                        <div id="summaryTableLoader" class="text-center py-5">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                            <p class="mt-2 text-muted">Please wait, loading summary...</p>
                        </div>

                        <div id="summaryTableContainer" style="display:none;">
                            <div class="d-flex align-items-end gap-3 mb-3 flex-wrap">
                                <div>
                                    <label for="filterSummaryCourse" class="form-label mb-1">Filter by Course:</label>
                                    <select id="filterSummaryCourse" class="form-select form-select-sm">
                                        <option value="">All Courses</option>
                                        <?php foreach ($courses as $c): ?>
                                            <option value="<?= htmlspecialchars($c) ?>"><?= htmlspecialchars($c) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                                <div>
                                    <label for="filterSummarySection" class="form-label mb-1">Filter by Section:</label>
                                    <select id="filterSummarySection" class="form-select form-select-sm">
                                        <option value="">All Sections</option>
                                        <?php foreach ($sectionsFilter as $s): ?>
                                            <option value="<?= htmlspecialchars($s) ?>"><?= htmlspecialchars($s) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                                <div>
                                    <label for="filterSummarySubject" class="form-label mb-1">Filter by Subject:</label>
                                    <select id="filterSummarySubject" class="form-select form-select-sm">
                                        <option value="">All Subjects</option>
                                        <?php foreach ($subjects as $sub): ?>
                                            <option value="<?= htmlspecialchars($sub) ?>"><?= htmlspecialchars($sub) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                                <button id="resetSummaryFilters" class="btn btn-secondary btn-sm">
                                    <i class="bi bi-recycle"></i> Reset Filters
                                </button>
                            </div>

                            <div class="table-responsive">
                                <table id="summaryTable" class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th>No.</th>
                                            <th>Student Number</th>
                                            <th>Full Name</th>
                                            <th>Course</th>
                                            <th>Section</th>
                                            <th>Subject</th>
                                            <th>Total Attendance</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php $counter = 1; foreach ($summaryData as $row): ?>
                                            <?php $cleanSec = cleanSection($row['section']); ?>
                                            <tr>
                                                <td><?= $counter++ ?></td>
                                                <td><?= htmlspecialchars($row['student_no']) ?></td>
                                                <td><?= htmlspecialchars($row['fullname']) ?></td>
                                                <td><?= htmlspecialchars($row['course']) ?></td>
                                                <td><?= htmlspecialchars($cleanSec) ?></td>
                                                <td><?= htmlspecialchars($row['subject'] ?? 'N/A') ?></td>
                                                <td><?= htmlspecialchars($row['total_attendance']) ?></td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    <?php else: ?>
                        <p class="text-muted">No attendance data available for your assigned section(s).</p>
                    <?php endif; ?>
                </div>
            </div>

        </div><!-- /tab-content -->
    </div><!-- /content -->

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="../assets/js/comingSoon.js"></script>
    <script src="../assets/js/logout.js"></script>
    <script src="../assets/js/toggleSidebar.js"></script>
    <?php
    // Auto cache-busting: browser re-fetches whenever the file changes.
    $js = fn($f) => "../assets/js/$f?v=" . filemtime(__DIR__ . "/../assets/js/$f");
    ?>
    <script src="<?= $js('datatables.js') ?>"></script>
    <script src="<?= $js('delete_attendance.js') ?>"></script>
    <script src="<?= $js('filter.js') ?>"></script>
</body>
</html>