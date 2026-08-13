<?php
// ============================================================
// Absence report: students in a section at or above an absence
// threshold, with a per-subject breakdown.
//
// Counting lives in includes/absences.php and is shared with
// api/get_absences_data.php, so the modal and this PDF cannot drift
// apart. Page furniture is shared with export_pdf.php — see
// includes/pdf_report.php.
// ============================================================

session_start();
include __DIR__ . "/../includes/db_connect.php";
include __DIR__ . "/../includes/permissions.php";
requirePermission('attendance.export', '../pages/dashboard.php');
include __DIR__ . "/../includes/systemConfig.php";
require_once __DIR__ . '/../includes/absences.php';
require __DIR__ . '/../includes/pdf_report.php';

date_default_timezone_set('Asia/Manila');

if (!isset($_SESSION['user_id'])) {
    header("Location: ../index.php");
    exit;
}

$user_id   = $_SESSION['user_id'];
$role      = $_SESSION['role'] ?? '';
$user_name = $_SESSION['user_name'] ?? $_SESSION['name'] ?? 'Unknown';

$full_section = $_POST['section']      ?? '';
$min_absences = isset($_POST['min_absences']) ? (int) $_POST['min_absences'] : 3;
$subject      = trim($_POST['subject'] ?? '');

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

if (!absence_can_access($conn, $role, $user_id, $course, $section)) {
    $_SESSION['error_message'] = "Access denied";
    header("Location: ../pages/dashboard.php");
    exit;
}

$allowed = ($role === 'admin') ? [] : absence_instructor_subjects($conn, $user_id);

if ($subject !== '' && $role !== 'admin' && !in_array($subject, $allowed, true)) {
    $_SESSION['error_message'] = "That subject is not assigned to you.";
    header("Location: ../pages/dashboard.php");
    exit;
}

$report = absence_report($conn, $course, $section, [
    'allowed_subjects' => $allowed,
    'subject'          => $subject,
    'min_absences'     => $min_absences,
    'scope_required'   => $role !== 'admin',
]);

$rows           = $report['students'];
$total_sessions = $report['total_sessions'];
$section_size   = $report['section_size'];
$subjects       = $report['subjects'];

$listed  = count($rows);
$at_risk = 0;
$worst   = 0;
$sum     = 0;

foreach ($rows as $r) {
    $sum += $r['absences'];
    if ($r['absences'] >= 5) $at_risk++;
    if ($r['absences'] > $worst) $worst = $r['absences'];
}

$avg   = $listed > 0 ? round($sum / $listed, 1) : 0;
$share = $section_size > 0 ? round(($listed / $section_size) * 100, 1) : 0;

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
    'Section'        => $full_section,
    'Subject'        => $subject !== '' ? $subject : 'All subjects (' . count($subjects) . ')',
    'Sessions held'  => (string) $total_sessions,
]);

$pdf->StatCards([
    'Section Size'   => [(string) $section_size, 'plain'],
    'Flagged'        => [(string) $listed, $listed > 0 ? 'warn' : 'ok'],
    'At Risk (5+)'   => [(string) $at_risk, $at_risk > 0 ? 'bad' : 'ok'],
    'Share of Class' => [$share . '%', $share >= 25 ? 'bad' : ($share > 0 ? 'warn' : 'ok')],
]);

// A session is one subject on one day. Spelling that out matters: the
// numbers here are larger than the old report's for the same data,
// and a reader who does not know why will assume one of them is wrong.
$pdf->SetFont('Arial', 'I', 7.5);
$pdf->SetTextColor(120, 128, 138);
$pdf->MultiCell(0, 4, ReportPDF::txt(
    'A session is one subject on one day. A student who attends one subject but misses another '
    . 'on the same day is absent for that session.'
), 0, 'L');
$pdf->SetTextColor(0, 0, 0);
$pdf->Ln(3);

$pdf->BlockTitle($subject !== '' ? "Flagged students - {$subject}" : 'Flagged students (all subjects)');

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
        $rate = $total_sessions > 0 ? round(($row['absences'] / $total_sessions) * 100, 1) : 0;

        $pdf->SetFillColor(247, 249, 251);

        // 5+ absences is the line the school acts on, so those rows
        // are red and bold rather than needing the number read.
        if ($row['absences'] >= 5) {
            $pdf->SetTextColor(185, 28, 28);
            $pdf->SetFont('Arial', 'B', 9);
        } else {
            $pdf->SetTextColor(0, 0, 0);
            $pdf->SetFont('Arial', '', 9);
        }

        $pdf->Cell(10, 7.5, $count,                             1, 0, 'C', $fill);
        $pdf->Cell(30, 7.5, ReportPDF::txt($row['student_no']), 1, 0, 'C', $fill);
        $pdf->Cell(68, 7.5, $pdf->fit($row['fullname'], 68),    1, 0, 'L', $fill);
        $pdf->Cell(22, 7.5, ReportPDF::txt($row['course']),     1, 0, 'C', $fill);
        $pdf->Cell(20, 7.5, (string) $row['attended'],          1, 0, 'C', $fill);
        $pdf->Cell(20, 7.5, (string) $row['absences'],          1, 0, 'C', $fill);
        $pdf->Cell(20, 7.5, $rate . '%',                        1, 1, 'C', $fill);

        $count++;
        $fill = !$fill;
    }
    $pdf->SetTextColor(0, 0, 0);
}
$pdf->EndTableBody();

// ── Breakdown by subject ──────────────────────────────────
// The point of the whole exercise: the overall count says a student
// is missing class, this says WHICH class. Skipped when the report is
// already about one subject, where it would just repeat the table.
if ($subject === '' && count($subjects) > 1) {
    $pdf->Ln(6);
    $pdf->BlockTitle('Breakdown by subject');

    $pdf->SetFont('Arial', 'I', 7.5);
    $pdf->SetTextColor(120, 128, 138);
    $pdf->MultiCell(0, 4, ReportPDF::txt(
        'Where each flagged student above lost their sessions. A student may appear under more than one subject.'
    ), 0, 'L');
    $pdf->SetTextColor(0, 0, 0);

    foreach ($subjects as $s) {
        // Every flagged student with ANY absence in this subject —
        // not only those over the threshold within it. The threshold
        // is applied to the total, so a student flagged for 3 spread
        // across two subjects (2 + 1) would otherwise appear in the
        // table above and then nowhere below, leaving the reader
        // unable to see where the 3 came from.
        $inSubject = [];
        foreach ($rows as $row) {
            foreach ($row['breakdown'] as $b) {
                if ($b['subject'] === $s['subject'] && $b['absences'] > 0) {
                    $inSubject[] = [$row, $b];
                }
            }
        }
        usort($inSubject, fn($x, $y) => $y[1]['absences'] <=> $x[1]['absences']);

        // Keep a heading with at least its first row.
        if ($pdf->GetY() > $pdf->GetPageHeight() - 45) $pdf->AddPage();

        $pdf->Ln(2);
        $pdf->SetFont('Arial', 'B', 9);
        $pdf->SetTextColor(31, 122, 60);
        $label = ($s['subject'] === '' ? '(no subject recorded)' : $s['subject'])
               . '  -  ' . $s['sessions'] . ' session' . ($s['sessions'] === 1 ? '' : 's') . ' held';
        $pdf->Cell(0, 6, ReportPDF::txt($label), 0, 1, 'L');
        $pdf->SetTextColor(0, 0, 0);

        $pdf->setTableColumns([
            [10, '#', 'C'], [30, 'Student No.', 'C'], [90, 'Name', 'L'],
            [30, 'Attended', 'C'], [30, 'Absent', 'C'],
        ]);
        $pdf->TableHead();
        $pdf->BeginTableBody();

        if (empty($inSubject)) {
            $pdf->EmptyRow('None of the flagged students has missed this subject.');
        } else {
            $n = 1; $fill = false;
            foreach ($inSubject as [$row, $b]) {
                $pdf->SetFillColor(247, 249, 251);
                if ($b['absences'] >= 5) {
                    $pdf->SetTextColor(185, 28, 28);
                    $pdf->SetFont('Arial', 'B', 9);
                } else {
                    $pdf->SetTextColor(0, 0, 0);
                    $pdf->SetFont('Arial', '', 9);
                }

                $pdf->Cell(10, 7, $n++,                                 1, 0, 'C', $fill);
                $pdf->Cell(30, 7, ReportPDF::txt($row['student_no']),   1, 0, 'C', $fill);
                $pdf->Cell(90, 7, $pdf->fit($row['fullname'], 90),      1, 0, 'L', $fill);
                $pdf->Cell(30, 7, $b['attended'] . ' / ' . $b['sessions'], 1, 0, 'C', $fill);
                $pdf->Cell(30, 7, (string) $b['absences'],              1, 1, 'C', $fill);
                $fill = !$fill;
            }
            $pdf->SetTextColor(0, 0, 0);
        }
        $pdf->EndTableBody();
    }
}

// ── Summary ───────────────────────────────────────────────
if ($listed > 0) {
    if ($pdf->GetY() > $pdf->GetPageHeight() - 60) $pdf->AddPage();

    $pdf->Ln(5);
    $pdf->BlockTitle('Summary');

    $pdf->SetFillColor(248, 250, 252);
    $pdf->SetDrawColor(225, 229, 234);

    $lines = [
        'Students flagged' => "{$listed} of {$section_size} in the section ({$share}%)",
        'Average absences' => "{$avg} of {$total_sessions} sessions",
        'Highest absences' => "{$worst} of {$total_sessions} sessions",
        'At risk (5+)'     => "{$at_risk} student" . ($at_risk === 1 ? '' : 's'),
        'Subjects covered' => $subject !== '' ? $subject : count($subjects) . ' subject' . (count($subjects) === 1 ? '' : 's'),
    ];

    foreach ($lines as $label => $value) {
        $pdf->SetFont('Arial', '', 9);
        $pdf->SetTextColor(90, 98, 108);
        $pdf->Cell(60, 7, ReportPDF::txt($label), 1, 0, 'L', true);
        $pdf->SetFont('Arial', 'B', 9);
        $pdf->SetTextColor(17, 24, 39);
        $pdf->Cell(130, 7, $pdf->fit($value, 130), 1, 1, 'L', true);
    }
    $pdf->SetTextColor(0, 0, 0);
}

$slug     = $subject !== '' ? '_' . preg_replace('/[^A-Za-z0-9]+/', '', $subject) : '';
$filename = "Absences_Report_{$full_section}{$slug}_" . date('Y-m-d') . ".pdf";

$pdf->AddSignature();
$pdf->Output('D', $filename);
