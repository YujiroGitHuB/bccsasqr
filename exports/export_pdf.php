<?php
// ============================================================
// Attendance report for one subject, section, and date.
//
// The page furniture (letterhead, title, footer, table headings,
// stat cards) lives in includes/pdf_report.php and is shared with
// export_absences_pdf.php — this file is the query and the rows.
// ============================================================

include __DIR__ . "/../includes/db_connect.php";
session_start();
include __DIR__ . "/../includes/permissions.php";
requirePermission('attendance.export', '../pages/dashboard.php');
include __DIR__ . "/../includes/systemConfig.php";
require __DIR__ . '/../includes/pdf_report.php';

date_default_timezone_set('Asia/Manila');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') exit;
if (!isset($_SESSION['user_id'])) {
    header("Location: ../index.php");
    exit;
}

$full_section = $_POST['section'] ?? '';
$subject      = $_POST['subject'] ?? '';
$status       = $_POST['status']  ?? 'all';
$date         = $_POST['date']    ?? date('Y-m-d');
$user_id      = (int) $_SESSION['user_id'];
$exported_by  = $_SESSION['user_name'] ?? $_SESSION['name'] ?? 'Unknown';

// "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = trim($parts[0] ?? '');
$section = trim($parts[1] ?? $full_section);

// ── Stats ─────────────────────────────────────────────────
// The report used to end with a single "Total Present: N" line,
// which says nothing about how big the class is. These three
// numbers are what the count actually has to be read against.
$stmt = $conn->prepare("SELECT COUNT(*) AS n FROM students_tbl WHERE course = ? AND section = ?");
$stmt->bind_param("ss", $course, $section);
$stmt->execute();
$enrolled = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
$stmt->close();

$stmt = $conn->prepare("
    SELECT COUNT(DISTINCT student_no) AS n
    FROM attendance_tbl
    WHERE course = ? AND section = ? AND subject = ? AND user_id = ? AND DATE(`date`) = ?
");
$stmt->bind_param("sssis", $course, $section, $subject, $user_id, $date);
$stmt->execute();
$present_count = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
$stmt->close();

$absent_count = max(0, $enrolled - $present_count);
$rate         = $enrolled > 0 ? round(($present_count / $enrolled) * 100, 1) : 0.0;

// ── Rows ──────────────────────────────────────────────────
if ($status === 'absent') {
    $sql = "
        SELECT s.student_no, s.fullname, s.course, s.section
        FROM students_tbl s
        WHERE s.course = ? AND s.section = ?
          AND s.student_no NOT IN (
              SELECT student_no FROM attendance_tbl
              WHERE course = ? AND section = ? AND subject = ? AND user_id = ? AND DATE(`date`) = ?
          )
        ORDER BY s.fullname ASC
    ";
    $report_title = 'Absent Students Report';
    $filename     = "Absent_{$subject}_{$full_section}_" . date('Y-m-d', strtotime($date)) . ".pdf";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssis", $course, $section, $course, $section, $subject, $user_id, $date);
} else {
    $sql = "
        SELECT date, student_no, name, course, section, subject, time_in
        FROM attendance_tbl
        WHERE course = ? AND section = ? AND subject = ? AND user_id = ? AND DATE(`date`) = ?
        ORDER BY name ASC
    ";
    $report_title = $status === 'present' ? 'Present Students Report' : 'Student Attendance Report';
    $prefix       = $status === 'present' ? 'Present' : 'Attendance';
    $filename     = "{$prefix}_{$subject}_{$full_section}_" . date('Y-m-d', strtotime($date)) . ".pdf";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssis", $course, $section, $subject, $user_id, $date);
}

$stmt->execute();
$result      = $stmt->get_result();
$total_count = $result->num_rows;

// ── Build ─────────────────────────────────────────────────
$pdf = new ReportPDF('P', 'mm', 'A4');
$pdf->loadBranding($system);
$pdf->setReportTitle($report_title, date('l, F d, Y', strtotime($date)));
$pdf->setPreparedBy($exported_by);
$pdf->SetMargins(ReportPDF::MARGIN, 10, ReportPDF::MARGIN);
$pdf->SetAutoPageBreak(true, 20);
$pdf->AliasNbPages();
$pdf->AddPage();

$pdf->MetaBar([
    'Subject' => $subject !== '' ? $subject : '-',
    'Section' => $full_section !== '' ? $full_section : '-',
    'Date'    => date('F d, Y', strtotime($date)),
]);

// The rate is coloured by how bad it is, so the reader does not have
// to compare it against anything to know whether it needs attention.
$rateTone = $rate >= 90 ? 'ok' : ($rate >= 75 ? 'warn' : 'bad');

$pdf->StatCards([
    'Enrolled'        => [(string) $enrolled, 'plain'],
    'Present'         => [(string) $present_count, 'ok'],
    'Absent'          => [(string) $absent_count, $absent_count > 0 ? 'bad' : 'plain'],
    'Attendance Rate' => [$rate . '%', $rateTone],
]);

$pdf->BlockTitle($status === 'absent' ? 'Absent students' : 'Attendance records');

if ($status === 'absent') {
    $pdf->setTableColumns([
        [12, '#', 'C'], [34, 'Student No.', 'C'], [90, 'Name', 'L'],
        [26, 'Course', 'C'], [28, 'Section', 'C'],
    ]);
} else {
    $pdf->setTableColumns([
        [12, '#', 'C'], [32, 'Student No.', 'C'], [76, 'Name', 'L'],
        [24, 'Course', 'C'], [46, 'Time In', 'C'],
    ]);
}

$pdf->TableHead();
$pdf->BeginTableBody();

$pdf->SetFont('Arial', '', 9);
$fill = false;
$i    = 1;

if ($total_count === 0) {
    $pdf->EmptyRow($status === 'absent'
        ? 'No absences recorded for this subject on this date.'
        : 'No attendance was recorded for this subject on this date.');
} else {
    while ($row = $result->fetch_assoc()) {
        $pdf->SetFillColor(247, 249, 251);

        if ($status === 'absent') {
            $pdf->Cell(12, 7.5, $i++,                                1, 0, 'C', $fill);
            $pdf->Cell(34, 7.5, ReportPDF::txt($row['student_no']),  1, 0, 'C', $fill);
            $pdf->Cell(90, 7.5, $pdf->fit($row['fullname'], 90),     1, 0, 'L', $fill);
            $pdf->Cell(26, 7.5, ReportPDF::txt($row['course']),      1, 0, 'C', $fill);
            $pdf->Cell(28, 7.5, ReportPDF::txt($row['section']),     1, 1, 'C', $fill);
        } else {
            $pdf->Cell(12, 7.5, $i++,                                1, 0, 'C', $fill);
            $pdf->Cell(32, 7.5, ReportPDF::txt($row['student_no']),  1, 0, 'C', $fill);
            $pdf->Cell(76, 7.5, $pdf->fit($row['name'], 76),         1, 0, 'L', $fill);
            $pdf->Cell(24, 7.5, ReportPDF::txt($row['course']),      1, 0, 'C', $fill);
            $pdf->Cell(46, 7.5, date('h:i A', strtotime($row['time_in'])), 1, 1, 'C', $fill);
        }
        $fill = !$fill;
    }
}

$pdf->EndTableBody();

// ── Total ─────────────────────────────────────────────────
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->SetFillColor(238, 242, 246);
$pdf->SetTextColor(17, 24, 39);
$label = $status === 'absent' ? 'Total absent' : 'Total listed';
$pdf->Cell(164, 8, ReportPDF::txt($label), 1, 0, 'R', true);
$pdf->Cell(26,  8, (string) $total_count,   1, 1, 'C', true);
$pdf->SetTextColor(0, 0, 0);

$pdf->AddSignature();
$pdf->Output('D', $filename);
