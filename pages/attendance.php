<?php require_once __DIR__ . '/../includes/asset.php';

session_start();
include "../includes/permissions.php";
include __DIR__ . "/../includes/check_user_status.php";
include __DIR__ . "/../includes/auth.php";
include __DIR__ . "/../includes/db_connect.php";
requirePermission('attendance.view');

$user_id = (int)$_SESSION['user_id'];

// Whether the delete controls (row buttons, checkboxes, Delete Selected)
// are rendered at all. crud/delete_attendance.php and
// crud/delete_selected_attendance.php enforce the same permission.
$canDeleteAttendance = can('attendance.delete');

// Helper: strip course prefix from section (e.g. "BSIT-2A" → "2A", "2A" → "2A")
function cleanSection($section) {
    return preg_replace('/^[A-Z]+-/', '', $section);
}

// ── Date window ───────────────────────────────────────────────
// This used to render the ENTIRE attendance_tbl on one page. Over a
// semester that is thousands of rows of HTML per page load, getting
// slower the more people attend. The default is the last 30 days;
// From/To can widen it.
$DEFAULT_WINDOW_DAYS = 30;

// Accept only a real YYYY-MM-DD so junk cannot get through.
$validDate = function ($v) {
    if (!is_string($v)) return null;
    $v = trim($v);
    $d = DateTime::createFromFormat('Y-m-d', $v);
    return ($d && $d->format('Y-m-d') === $v) ? $v : null;
};

$from = $validDate($_GET['from'] ?? null) ?? date('Y-m-d', strtotime("-{$DEFAULT_WINDOW_DAYS} days"));
$to   = $validDate($_GET['to']   ?? null) ?? date('Y-m-d');

// If the order is reversed, swap them — better than showing nothing.
if ($from > $to) {
    [$from, $to] = [$to, $from];
}

// A section can be preselected by a link — the dashboard section cards
// point here. It only preselects the existing dropdown (which filters
// the loaded rows in JavaScript); the rows fetched are still decided by
// the date window alone.
$preSection = cleanSection(trim($_GET['section'] ?? ''));
?>
<!doctype html>
<html lang="en">

<head>
    <?php include __DIR__ . "/../includes/header.php" ?>
    <link rel="stylesheet" href="<?= asset('../assets/css/attendance-page.css') ?>">
</head>

<body>
    <?php include __DIR__ . "/../components/sidebar.php"; ?>
    <div class="content att-page" id="content">
        <?php include("../components/topBar.php"); ?>

        <div class="att-hero">
            <div class="att-hero-icon"><i class="bi bi-journal-text"></i></div>
            <div class="att-hero-text">
                <h2>Attendance</h2>
                <p>Every QR scan lands here. Filter by date and section, then export.</p>
            </div>
            <div class="att-chips">
                <span class="att-chip">
                    <i class="bi bi-calendar-range"></i>
                    <?= date('M j', strtotime($from)) ?> – <?= date('M j, Y', strtotime($to)) ?>
                </span>
            </div>
        </div>

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
                <div>
                    <div class="att-toolbar">
                        <div class="att-toolbar-title">
                            <i class="bi bi-table"></i> Attendance Records
                        </div>
                        <div class="att-actions">
                            <?php if (can('attendance.delete')): ?>
                            <button id="deleteSelected" class="att-btn danger" disabled>
                                <i class="bi bi-trash"></i>
                                <span class="btn-text">Delete Selected</span>
                            </button>
                            <?php endif; ?>
                            <?php if (isAdmin()): ?>
                                <button id="deleteAll" class="att-btn danger">
                                    <i class="bi bi-trash-fill"></i>
                                    <span class="btn-text">Delete All</span>
                                </button>
                            <?php endif; ?>
                        </div>
                    </div>

                    <div class="att-card">
                        <div id="tableLoader" class="text-center py-5">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Loading...</span>
                            </div>
                            <p class="mt-2 text-muted">Please wait, loading data...</p>
                        </div>

                        <?php
                        // Already bounded by $from..$to — see the date window above.
                        if (isAdmin()) {
                            $stmt = $conn->prepare("
                                SELECT id, date, student_no, name, course, section, time_in, subject
                                FROM attendance_tbl
                                WHERE date BETWEEN ? AND ?
                                ORDER BY date DESC
                            ");
                            $stmt->bind_param("ss", $from, $to);
                        } else {
                            $stmt = $conn->prepare("
                                SELECT id, date, student_no, name, course, section, time_in, subject
                                FROM attendance_tbl
                                WHERE user_id = ?
                                  AND date BETWEEN ? AND ?
                                ORDER BY date DESC
                            ");
                            $stmt->bind_param("iss", $user_id, $from, $to);
                        }
                        $stmt->execute();
                        $result   = $stmt->get_result();
                        $rowCount = $result->num_rows;
                        ?>

                        <div id="tableContainer" style="display:none;">
                            <!-- Date window: reloads the page, so only rows inside
                                 the range are fetched from the database. -->
                            <!-- The date window (which reloads, because the range
                                 decides which rows are fetched from the database)
                                 and the section filter (JS only, within the data
                                 already fetched) now sit in one row. -->
                            <div class="att-filters">
                                <form method="get" class="att-filter-form">
                                    <div>
                                        <label for="fromDate" class="form-label">From</label>
                                        <input type="date" id="fromDate" name="from"
                                               value="<?= htmlspecialchars($from) ?>"
                                               class="form-control form-control-sm">
                                    </div>
                                    <div>
                                        <label for="toDate" class="form-label">To</label>
                                        <input type="date" id="toDate" name="to"
                                               value="<?= htmlspecialchars($to) ?>"
                                               class="form-control form-control-sm">
                                    </div>
                                    <button type="submit" class="att-btn primary">
                                        <i class="bi bi-search"></i> Show
                                    </button>
                                    <a href="attendance.php" class="att-btn ghost">
                                        Last 30 days
                                    </a>
                                </form>

                                <div class="att-filter-group">
                                    <label for="filterSection" class="form-label">Section</label>
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
                                            $sel  = ($preSection !== '' && $cleanSec === $preSection) ? " selected" : "";
                                            echo "<option value='{$full}'{$sel}>{$full}</option>";
                                        }
                                        ?>
                                    </select>
                                </div>

                                <button id="resetFilters" class="att-btn ghost">
                                    <i class="bi bi-recycle"></i> Reset Filters
                                </button>

                                <span class="att-count">
                                    <?= number_format($rowCount) ?> record<?= $rowCount === 1 ? '' : 's' ?> loaded
                                </span>
                            </div>

                            <div class="table-responsive">
                                <table id="example" class="table table-striped" style="width:100%;">
                                    <thead>
                                        <tr>
                                            <?php
                                            // The checkbox and Action columns are kept even without
                                            // the delete permission, only emptied: the DataTables
                                            // config in assets/js/datatables.js addresses columns by
                                            // index, and dropping one here would shift every target.
                                            ?>
                                            <th class="text-center"><?php if ($canDeleteAttendance): ?><input type="checkbox" id="selectAllAttendance" title="Select all"><?php endif; ?></th>
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
                                                <td class="text-center"><?php if ($canDeleteAttendance): ?><input type="checkbox" class="rowCheck" value="<?= $row['id'] ?>"><?php endif; ?></td>
                                                <td><?= $counter++ ?></td>
                                                <td><?= htmlspecialchars($row['date']) ?></td>
                                                <td><?= htmlspecialchars($row['student_no']) ?></td>
                                                <td><?= htmlspecialchars($row['name']) ?></td>
                                                <td><?= htmlspecialchars($row['course']) ?></td>
                                                <td><?= htmlspecialchars($cleanSec) ?></td>
                                                <td><?= htmlspecialchars($row['time_in']) ?></td>
                                                <td><?= htmlspecialchars($row['subject']) ?></td>
                                                <td>
                                                    <?php if ($canDeleteAttendance): ?>
                                                    <button class="btn-delete" data-id="<?= $row['id'] ?>">
                                                        <i class="bi bi-trash"></i>
                                                    </button>
                                                    <?php endif; ?>
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
                <div>
                    <div class="att-toolbar">
                        <div class="att-toolbar-title">
                            <i class="bi bi-bar-chart"></i> Attendance Summary
                        </div>
                        <?php if (can('attendance.export')): ?>
                        <div class="att-actions">
                            <!-- The three hidden inputs are filled from the
                                 filter dropdowns on submit (assets/js/datatables.js),
                                 so the PDF covers what is on screen. The rows
                                 themselves are re-queried server-side; only the
                                 filter values travel. -->
                            <form action="../exports/export_summary_pdf.php" method="POST"
                                  id="exportSummaryForm">
                                <input type="hidden" name="course"  id="exportSummaryCourse">
                                <input type="hidden" name="section" id="exportSummarySection">
                                <input type="hidden" name="subject" id="exportSummarySubject">
                                <button type="submit" class="att-btn primary">
                                    <i class="bi bi-file-earmark-pdf"></i>
                                    <span class="btn-text">Export PDF</span>
                                </button>
                            </form>
                        </div>
                        <?php endif; ?>
                    </div>
                    <div class="att-card">

                    <?php
                    // The summary is fetched by get_summary_ajax.php when the
                    // tab is opened. The GROUP BY used to run here on every
                    // page load even with the tab closed, rendering every row
                    // into the HTML.
                    ?>

                    <div id="summaryTableLoader" class="text-center py-5" style="display:none;">
                        <div class="spinner-border text-primary" role="status">
                            <span class="visually-hidden">Loading...</span>
                        </div>
                        <p class="mt-2 text-muted">Please wait, loading summary...</p>
                    </div>

                    <p id="summaryTableEmpty" class="text-muted" style="display:none;">
                        No attendance data available for your assigned section(s).
                    </p>

                    <div id="summaryTableContainer" style="display:none;">
                        <div class="d-flex align-items-end gap-3 mb-3 flex-wrap">
                            <div>
                                <label for="filterSummaryCourse" class="form-label mb-1">Filter by Course:</label>
                                <select id="filterSummaryCourse" class="form-select form-select-sm">
                                    <option value="">All Courses</option>
                                </select>
                            </div>
                            <div>
                                <label for="filterSummarySection" class="form-label mb-1">Filter by Section:</label>
                                <select id="filterSummarySection" class="form-select form-select-sm">
                                    <option value="">All Sections</option>
                                </select>
                            </div>
                            <div>
                                <label for="filterSummarySubject" class="form-label mb-1">Filter by Subject:</label>
                                <select id="filterSummarySubject" class="form-select form-select-sm">
                                    <option value="">All Subjects</option>
                                </select>
                            </div>
                            <button id="resetSummaryFilters" class="btn btn-secondary btn-sm">
                                <i class="bi bi-recycle"></i> Reset Filters
                            </button>
                        </div>

                        <div class="table-responsive">
                            <table id="summaryTable" class="table table-striped" style="width:100%;">
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
                                <tbody></tbody>
                            </table>
                        </div>
                    </div><!-- /summaryTableContainer -->
                </div><!-- /att-card -->
                </div><!-- /summary wrapper -->
            </div><!-- /tab-pane -->

        </div><!-- /tab-content -->
    </div><!-- /content -->

    <?php include __DIR__ . "/../includes/footer.php"; ?>
    <script src="<?= asset('../assets/js/comingSoon.js') ?>"></script>
    <script src="<?= asset('../assets/js/logout.js') ?>"></script>
    <script src="<?= asset('../assets/js/toggleSidebar.js') ?>"></script>
    <script src="<?= asset('../assets/js/datatables.js') ?>"></script>
    <script src="<?= asset('../assets/js/delete_attendance.js') ?>"></script>
    <script src="<?= asset('../assets/js/filter.js') ?>"></script>
</body>
</html>