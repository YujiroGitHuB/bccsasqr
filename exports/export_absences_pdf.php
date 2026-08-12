<?php
// ============================================================
// Absence report: students in a section at or above an absence
// threshold, with how much of the term they have missed.
//
// The page furniture is shared with export_pdf.php — see
// includes/pdf_report.php.
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/systemConfig.php";
require __DIR__ . '/../includes/pdf_report.php';

date_default_timezone_set('Asia/Manila');

if (!isset($_SESSION['user_id'])) {
    header("Location: ../index.php");
    exit;
}

$user_id   = $_SESSION['user_id'];
$role      = $_SESSION['role'];
$user_name = $_SESSION['user_name'] ?? $_SESSION['name'] ?? 'Unknown';

$full_section = $_POST['section']      ?? '';
$min_absences = isset($_POST['min_absences']) ? (int) $_POST['min_absences'] : 3;

if (empty($full_section)) {
    $_SESSION['error_message'] = "Section is required";
    header("Location: ../pages/dashboard.php");
    exit;
}

// "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = trim($parts[0] ?? '');
$section = trim($parts[1] ?? $full_section);

if (empty($course) || empty($section)) {
    $_SESSION['error_message'] = "Invalid section format.";
    header("Location: ../pages/dashboard.php");
    exit;
}

// ── Access check (instructor only) ───────────────────────
if ($role !== 'admin') {
    $check_stmt = $conn->prepare("
        SELECT COUNT(*) as cnt FROM instructor_section_tbl
        WHERE instructor_id = ? AND course = ? AND section = ?
    ");
    $check_stmt->bind_param("iss", $user_id, $course, $section);
    $check_stmt->execute();
    $has_access = $check_stmt->get_result()->fetch_assoc()['cnt'] > 0;

    if (!$has_access) {
        $_SESSION['error_message'] = "Access denied";
        header("Location: ../pages/dashboard.php");
        exit;
    }
}

// ── Subject filter (instructor only) ────────────────────
$subjects_filter = "";
if ($role !== 'admin') {
    $sq = $conn->prepare("
        SELECT s.subject_name
        FROM subjects_tbl s
        INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
        WHERE si.instructor_id = ?
    ");
    $sq->bind_param("i", $user_id);
    $sq->execute();
    $r = $sq->get_result();

    $subject_names = [];
    while ($row = $r->fetch_assoc()) {
        $subject_names[] = "'" . $conn->real_escape_string($row['subject_name']) . "'";
    }
    if (!empty($subject_names)) {
        $subjects_filter = "AND subject IN (" . implode(',', $subject_names) . ")";
    }
}

// ── Total unique class dates ──────────────────────────────
$stmt = $conn->prepare("
    SELECT COUNT(DISTINCT DATE(date)) as total_classes
    FROM attendance_tbl
    WHERE course = ? AND section = ?
    " . ($role === 'admin' ? '' : $subjects_filter) . "
");
$stmt->bind_param("ss", $course, $section);
$stmt->execute();
$total_classes = (int) $stmt->get_result()->fetch_assoc()['total_classes'];
$stmt->close();

// ── How big the section is ────────────────────────────────
// Needed to say what share of the class is being flagged — the old
// report printed a count with nothing to compare it against.
$stmt = $conn->prepare("SELECT COUNT(*) AS n FROM students_tbl WHERE course = ? AND section = ?");
$stmt->bind_param("ss", $course, $section);
$stmt->execute();
$section_size = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
$stmt->close();

// ── Students with absences >= min_absences ────────────────
$inner_filter = $role === 'admin' ? '' : $subjects_filter;
$students_query = "
    SELECT
        s.student_no,
        s.fullname,
        s.course,
        s.section,
        COALESCE(a.attended, 0)                     AS attended,
        $total_classes                              AS total_classes,
        ($total_classes - COALESCE(a.attended, 0))  AS absences
    FROM students_tbl s
    LEFT JOIN (
        SELECT student_no, COUNT(DISTINCT DATE(date)) AS attended
        FROM attendance_tbl
        WHERE course = ? AND section = ?
        $inner_filter
        GROUP BY student_no
    ) a ON s.student_no = a.student_no
    WHERE s.course = ? AND s.section = ?
    HAVING absences >= ?
    ORDER BY absences DESC, s.fullname ASC
";
$stmt = $conn->prepare($students_query);
$stmt->bind_param("ssssi", $course, $section, $course, $section, $min_absences);
$stmt->execute();
$result = $stmt->get_result();

// Buffered so the stat cards — which are drawn ABOVE the table — can
// be computed from the same rows.
$rows               = [];
$total_absences_sum = 0;
$at_risk            = 0;    // 5+ absences
$worst              = 0;

while ($row = $result->fetch_assoc()) {
    $rows[] = $row;
    $total_absences_sum += (int) $row['absences'];
    if ((int) $row['absences'] >= 5) $at_risk++;
    if ((int) $row['absences'] > $worst) $worst = (int) $row['absences'];
}

$listed       = count($rows);
$avg_absences = $listed > 0 ? round($total_absences_sum / $listed, 1) : 0;
$share        = $section_size > 0 ? round(($listed / $section_size) * 100, 1) : 0;

// ── Build ─────────────────────────────────────────────────
$pdf = new ReportPDF('P', 'mm', 'A4');
$pdf->loadBranding($system);
$pdf->setReportTitle('Absence Report', "Students with {$min_absences}+ absences");
$pdf->setPreparedBy($user_name);
$pdf->SetMargins(ReportPDF::MARGIN, 10, ReportPDF::MARGIN);
$pdf->SetAutoPageBreak(true, 20);
$pdf->AliasNbPages();
$pdf->AddPage();

$pdf->MetaBar([
    'Section'      => $full_section,
    'Classes held' => (string) $total_classes,
    'Threshold'    => $min_absences . ' absences or more',
]);

$pdf->StatCards([
    'Section Size'    => [(string) $section_size, 'plain'],
    'Flagged'         => [(string) $listed, $listed > 0 ? 'warn' : 'ok'],
    'At Risk (5+)'    => [(string) $at_risk, $at_risk > 0 ? 'bad' : 'ok'],
    'Share of Class'  => [$share . '%', $share >= 25 ? 'bad' : ($share > 0 ? 'warn' : 'ok')],
]);

$pdf->BlockTitle('Flagged students');

$pdf->setTableColumns([
    [10, '#', 'C'], [30, 'Student No.', 'C'], [68, 'Name', 'L'], [22, 'Course', 'C'],
    [20, 'Attended', 'C'], [20, 'Absent', 'C'], [20, 'Missed', 'C'],
]);
$pdf->TableHead();
$pdf->BeginTableBody();

if ($listed === 0) {
    $pdf->EmptyRow("No students in {$full_section} have {$min_absences} or more absences.");
} else {
    $count = 1;
    $fill  = false;

    foreach ($rows as $row) {
        $absences     = (int) $row['absences'];
        $absence_rate = $total_classes > 0 ? round(($absences / $total_classes) * 100, 1) : 0;

        $pdf->SetFillColor(247, 249, 251);

        // 5+ absences is the line the school acts on, so those rows
        // are red and bold rather than needing the number read.
        if ($absences >= 5) {
            $pdf->SetTextColor(185, 28, 28);
            $pdf->SetFont('Arial', 'B', 9);
        } else {
            $pdf->SetTextColor(0, 0, 0);
            $pdf->SetFont('Arial', '', 9);
        }

        $pdf->Cell(10, 7.5, $count,                                  1, 0, 'C', $fill);
        $pdf->Cell(30, 7.5, ReportPDF::txt($row['student_no']),      1, 0, 'C', $fill);
        // After SetFont above, so the wider bold face used for the
        // 5+ rows is what the width is measured against.
        $pdf->Cell(68, 7.5, $pdf->fit($row['fullname'], 68),         1, 0, 'L', $fill);
        $pdf->Cell(22, 7.5, ReportPDF::txt($row['course']),          1, 0, 'C', $fill);
        $pdf->Cell(20, 7.5, (string) $row['attended'],               1, 0, 'C', $fill);
        $pdf->Cell(20, 7.5, (string) $absences,                      1, 0, 'C', $fill);
        $pdf->Cell(20, 7.5, $absence_rate . '%',                     1, 1, 'C', $fill);

        $count++;
        $fill = !$fill;
    }
    $pdf->SetTextColor(0, 0, 0);
}

$pdf->EndTableBody();

// ── Summary ───────────────────────────────────────────────
if ($listed > 0) {
    $pdf->Ln(5);
    $pdf->BlockTitle('Summary');

    $pdf->SetFont('Arial', '', 9);
    $pdf->SetFillColor(248, 250, 252);
    $pdf->SetDrawColor(225, 229, 234);

    $lines = [
        'Students flagged'  => "{$listed} of {$section_size} in the section ({$share}%)",
        'Average absences'  => "{$avg_absences} of {$total_classes} classes",
        'Highest absences'  => "{$worst} of {$total_classes} classes",
        'At risk (5+)'      => "{$at_risk} student" . ($at_risk === 1 ? '' : 's'),
    ];

    foreach ($lines as $label => $value) {
        $pdf->SetFont('Arial', '', 9);
        $pdf->SetTextColor(90, 98, 108);
        $pdf->Cell(60, 7, ReportPDF::txt($label), 1, 0, 'L', true);
        $pdf->SetFont('Arial', 'B', 9);
        $pdf->SetTextColor(17, 24, 39);
        $pdf->Cell(130, 7, ReportPDF::txt($value), 1, 1, 'L', true);
    }
    $pdf->SetTextColor(0, 0, 0);
}

$filename = "Absences_Report_{$full_section}_" . date('Y-m-d') . ".pdf";

$pdf->AddSignature();
$pdf->Output('D', $filename);
