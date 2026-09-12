<?php
// ============================================================
// Attendance summary report — the Summary tab of
// pages/attendance.php, as a PDF.
//
// The page furniture (letterhead, title, meta bar, stat cards,
// table headings, signature) lives in includes/pdf_report.php and
// is shared with export_pdf.php and export_absences_pdf.php — this
// file is the query, the filters and the rows.
//
// The counts are re-run here rather than accepted from the browser.
// The tab holds its rows in a DataTable, so posting them back would
// have been fewer lines, but it would also let anyone edit a total
// before it landed on a signed report — and it would bypass the
// instructor scoping below.
// ============================================================

include __DIR__ . "/../includes/db_connect.php";
session_start();
include __DIR__ . "/../includes/permissions.php";
requirePermission('attendance.export', '../pages/dashboard.php');
include __DIR__ . "/../includes/systemConfig.php";
require __DIR__ . '/../includes/pdf_report.php';
require_once __DIR__ . "/../includes/attendance_summary.php";

date_default_timezone_set('Asia/Manila');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') exit;
if (!isset($_SESSION['user_id'])) {
    header("Location: ../index.php");
    exit;
}

$user_id     = (int) $_SESSION['user_id'];
$exported_by = $_SESSION['user_name'] ?? $_SESSION['name'] ?? 'Unknown';

// Same helper as pages/attendance.php and pages/get_summary_ajax.php:
// "BSIT-2A" → "2A".
function cleanSection($section) {
    return preg_replace('/^[A-Z]+-/', '', $section);
}

$fCourse  = trim($_POST['course']  ?? '');
$fSection = trim($_POST['section'] ?? '');
$fSubject = trim($_POST['subject'] ?? '');

// ── The summary ───────────────────────────────────────────
// The counting lives in includes/attendance_summary.php, which the
// Summary tab calls through pages/get_summary_ajax.php. It used to be
// written out here a second time, with a comment saying the two
// queries were deliberately identical — they cannot be kept identical
// by hand now that a row is a fraction, and a signed report that
// disagrees with the screen it was exported from is worse than no
// report.
//
// The scoping comes with it: an admin sees every student, an
// instructor only the sections assigned to them, counting only the
// attendance they recorded. The counts are still re-run here rather
// than accepted from the browser — the tab holds its rows in a
// DataTable, and posting them back would let anyone edit a total
// before it landed on a signed report.
$summaryData = attendance_summary_rows($conn, isAdmin(), $user_id);

// ── Filters ───────────────────────────────────────────────
// Applied in PHP rather than SQL because the Section dropdown holds
// CLEANED sections ("2A") while the column stores "BSIT-2A"; there is
// no way to match one against the other in the WHERE clause without
// rebuilding the prefix, and the prefix is not always the course.
//
// These compare exactly. The tab's dropdowns drive DataTables, whose
// column search is a substring match — so on screen a "2A" filter
// also shows "12A" if such a section exists. Exact is what the
// dropdown means, and a report has to be able to say what is in it.
$rows = [];

foreach ($summaryData as $row) {
    $cleanSec = cleanSection($row['section']);
    $subject  = ($row['subject'] !== null && $row['subject'] !== '') ? $row['subject'] : 'N/A';

    if ($fCourse  !== '' && $row['course'] !== $fCourse)  continue;
    if ($fSection !== '' && $cleanSec      !== $fSection) continue;
    if ($fSubject !== '' && $subject       !== $fSubject) continue;

    $rows[] = [
        'student_no'       => $row['student_no'],
        'fullname'         => $row['fullname'],
        'course'           => $row['course'],
        'section'          => $cleanSec,
        'subject'          => $subject,
        'attended'      => (int) $row['attended'],
        'sessions_held' => (int) $row['sessions_held'],
    ];
}

// ── Stats ─────────────────────────────────────────────────
// A row here is one student against one subject, so the row count on
// its own says very little — 40 rows can be 40 students or 8. The
// three below are what the total has to be read against.
$students = [];
$subjects = [];
$records  = 0;   // sessions attended
$expected = 0;   // sessions those were out of

foreach ($rows as $r) {
    $students[$r['student_no']] = true;
    if ($r['subject'] !== 'N/A') $subjects[$r['subject']] = true;
    $records  += $r['attended'];
    $expected += $r['sessions_held'];
}

$studentCount = count($students);
$subjectCount = count($subjects);
$average      = $studentCount > 0 ? round($records / $studentCount, 1) : 0.0;

// ── Build ─────────────────────────────────────────────────
// Landscape, unlike the other two reports: seven columns, two of
// which hold full names and subject titles. In portrait the name
// column drops to about 62mm and fit() starts truncating ordinary
// student names, which is not something a report should do.
$pdf = new ReportPDF('L', 'mm', 'A4');
$pdf->loadBranding($system);
$pdf->setReportTitle('Attendance Summary Report', date('l, F d, Y'));
$pdf->setPreparedBy($exported_by);
$pdf->SetMargins(ReportPDF::MARGIN, 10, ReportPDF::MARGIN);
$pdf->SetAutoPageBreak(true, 20);
$pdf->AliasNbPages();
$pdf->AddPage();

$pdf->MetaBar([
    'Course'  => $fCourse  !== '' ? $fCourse  : 'All courses',
    'Section' => $fSection !== '' ? $fSection : 'All sections',
    'Subject' => $fSubject !== '' ? $fSubject : 'All subjects',
]);

$pdf->StatCards([
    'Students'           => [(string) $studentCount, 'plain'],
    'Subjects'           => [(string) $subjectCount, 'plain'],
    'Sessions Attended'  => [$records . ' / ' . $expected, 'ok'],
    'Average / Student'  => [number_format($average, 1), 'plain'],
]);

$pdf->BlockTitle('Attendance per student and subject');

// Widths add up to 277mm — A4 landscape (297) less both 10mm margins.
$pdf->setTableColumns([
    [14, '#',            'C'],
    [38, 'Student No.',  'C'],
    [85, 'Full Name',    'L'],
    [28, 'Course',       'C'],
    [26, 'Section',      'C'],
    [60, 'Subject',      'L'],
    [26, 'Attendance',   'C'],
]);

$pdf->TableHead();
$pdf->BeginTableBody();

$pdf->SetFont('Arial', '', 9);
$fill = false;
$i    = 1;

if (empty($rows)) {
    $pdf->EmptyRow('No attendance summary matches these filters.');
} else {
    foreach ($rows as $r) {
        $pdf->SetFillColor(247, 249, 251);
        $pdf->Cell(14, 7.5, $i++,                               1, 0, 'C', $fill);
        $pdf->Cell(38, 7.5, ReportPDF::txt($r['student_no']),   1, 0, 'C', $fill);
        $pdf->Cell(85, 7.5, $pdf->fit($r['fullname'], 85),      1, 0, 'L', $fill);
        $pdf->Cell(28, 7.5, ReportPDF::txt($r['course']),       1, 0, 'C', $fill);
        $pdf->Cell(26, 7.5, ReportPDF::txt($r['section']),      1, 0, 'C', $fill);
        $pdf->Cell(60, 7.5, $pdf->fit($r['subject'], 60),       1, 0, 'L', $fill);
        $pdf->Cell(26, 7.5, $r['sessions_held'] > 0
            ? $r['attended'] . ' / ' . $r['sessions_held']
            : (string) $r['attended'],                       1, 1, 'C', $fill);
        $fill = !$fill;
    }
}

$pdf->EndTableBody();

// ── Total ─────────────────────────────────────────────────
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->SetFillColor(238, 242, 246);
$pdf->SetTextColor(17, 24, 39);
$pdf->Cell(251, 8, ReportPDF::txt('Sessions attended, out of sessions held'), 1, 0, 'R', true);
$pdf->Cell(26,  8, $records . ' / ' . $expected,                            1, 1, 'C', true);
$pdf->SetTextColor(0, 0, 0);

$pdf->AddSignature();

// The filters go in the filename so two exports taken minutes apart
// do not overwrite each other in the download folder.
$slug = function ($v) {
    $v = preg_replace('/[^A-Za-z0-9]+/', '-', (string) $v);
    return trim($v, '-');
};

$parts = array_filter([
    'Attendance_Summary',
    $fCourse  !== '' ? $slug($fCourse)  : '',
    $fSection !== '' ? $slug($fSection) : '',
    $fSubject !== '' ? $slug($fSubject) : '',
    date('Y-m-d'),
]);

$pdf->Output('D', implode('_', $parts) . '.pdf');
