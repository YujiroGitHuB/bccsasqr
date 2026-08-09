<?php
require('../includes/fpdf/fpdf.php');
include("../includes/db_connect.php");
session_start();

date_default_timezone_set('Asia/Manila');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') exit;

$full_section = $_POST['section'] ?? '';
$subject      = $_POST['subject'] ?? '';
$status       = $_POST['status']  ?? 'all';
$date         = $_POST['date']    ?? date('Y-m-d');
$user_id       = (int)$_SESSION['user_id'];
$exported_by   = $_SESSION['user_name'] ?? $_SESSION['name'] ?? 'Unknown';

// ✅ FIXED: split "BSIT-1A" → course="BSIT", section="1A"
$parts   = explode('-', $full_section, 2);
$course  = trim($parts[0] ?? '');
$section = trim($parts[1] ?? $full_section);

if ($status === 'present' || $status === 'all') {
    // ✅ FIXED: attendance_tbl has separate course + section columns
    $sql = "
        SELECT date, student_no, name, course, section, subject, time_in
        FROM attendance_tbl
        WHERE course = ? AND section = ?
          AND subject  = ?
          AND user_id  = ?
          AND DATE(`date`) = ?
        ORDER BY name ASC
    ";
    $report_title = $status === 'present' ? "Present Students Report" : "Student Attendance Report";
    $prefix       = $status === 'present' ? 'Present' : 'Attendance';
    $filename     = "{$prefix}_{$subject}_{$full_section}_" . date('Y-m-d', strtotime($date)) . ".pdf";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssis", $course, $section, $subject, $user_id, $date);

} elseif ($status === 'absent') {
    // ✅ FIXED: outer WHERE uses students_tbl.course + section
    //           subquery uses attendance_tbl.course + section
    $sql = "
        SELECT s.student_no, s.fullname, s.course, s.section
        FROM students_tbl s
        WHERE s.course   = ?
          AND s.section  = ?
          AND s.student_no NOT IN (
              SELECT student_no FROM attendance_tbl
              WHERE course   = ?
                AND section  = ?
                AND subject  = ?
                AND user_id  = ?
                AND DATE(`date`) = ?
          )
        ORDER BY s.fullname ASC
    ";
    $report_title = "Absent Students Report";
    $filename     = "Absent_{$subject}_{$full_section}_" . date('Y-m-d', strtotime($date)) . ".pdf";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssis", $course, $section, $course, $section, $subject, $user_id, $date);
}

$stmt->execute();
$result      = $stmt->get_result();
$total_count = $result->num_rows;

// ── PDF Class ─────────────────────────────────────────────
class PDF extends FPDF
{
    private $reportTitle;
    private $exportedBy = '';

    function setReportTitle($title) { $this->reportTitle = $title; }

    function Header()
    {
        $logo_left  = __DIR__ . '/../assets/images/bcc logo.png';
        $logo_right = __DIR__ . '/../assets/images/scc-logo.png';
        $logo_w = 22; $logo_h = 22; $top_y = 8;

        if (file_exists($logo_left))  $this->Image($logo_left,  10, $top_y, $logo_w, $logo_h);
        if (file_exists($logo_right)) $this->Image($logo_right, $this->GetPageWidth() - $logo_w - 10, $top_y, $logo_w, $logo_h);

        $this->SetY($top_y);
        $this->SetFont('Arial', 'B', 16);
        $this->Cell(0, 10, 'Binalatongan Community College', 0, 1, 'C');

        $this->SetFont('Arial', '', 12);
        $this->Cell(0, 7, $this->reportTitle, 0, 1, 'C');

        if ($this->GetY() < $top_y + $logo_h + 2) {
            $this->SetY($top_y + $logo_h + 2);
        }

        $this->Ln(3);
        $this->SetDrawColor(0, 0, 0);
        $this->Line(10, $this->GetY(), 200, $this->GetY());
        $this->Ln(5);
    }

    function Footer()
    {
        $this->SetY(-15);
        $this->SetFont('Arial', 'I', 8);
        $this->Cell(0, 10, 'Page ' . $this->PageNo() . '/{nb}', 0, 0, 'C');
    }

    function setExportedBy($name) { $this->exportedBy = $name; }

    function AddSignature()
    {
        $this->SetY(-45);
        $this->SetFont('Arial', '', 11);
        $this->Cell(0, 6, '______________________________', 0, 1, 'R');
        $this->SetFont('Arial', 'B', 11);
        $this->Cell(0, 6, $this->exportedBy, 0, 1, 'R');
        $this->SetFont('Arial', '', 10);
        $this->Cell(0, 6, 'Prepared by', 0, 1, 'R');
    }
}

$pdf = new PDF('P', 'mm', 'A4');
$pdf->setReportTitle($report_title);
$pdf->setExportedBy($exported_by);
$pdf->AliasNbPages();
$pdf->AddPage();

// ── Report info ───────────────────────────────────────────
$pdf->SetFont('Arial', '', 12);
$pdf->Cell(0, 8, "Subject: $subject",                           0, 1, 'L');
// ✅ FIXED: display full "BSIT-1A" not raw "1A"
$pdf->Cell(0, 8, "Section: $full_section",                      0, 1, 'L');
$pdf->Cell(0, 8, "Date: " . date('F d, Y', strtotime($date)),   0, 1, 'L');
$pdf->Cell(0, 8, "Status: " . ucfirst($status),                 0, 1, 'L');
$pdf->Ln(5);

// ── Table header ──────────────────────────────────────────
$pdf->SetFont('Arial', 'B', 11);
$pdf->SetFillColor(52, 73, 94);
$pdf->SetTextColor(255, 255, 255);

if ($status === 'absent') {
    $pdf->Cell(15, 10, '#',           1, 0, 'C', true);
    $pdf->Cell(40, 10, 'Student No',  1, 0, 'C', true);
    $pdf->Cell(70, 10, 'Name',        1, 0, 'C', true);
    $pdf->Cell(55, 10, 'Course',      1, 1, 'C', true);
} else {
    $pdf->Cell(15, 10, '#',           1, 0, 'C', true);
    $pdf->Cell(35, 10, 'Student No',  1, 0, 'C', true);
    $pdf->Cell(60, 10, 'Name',        1, 0, 'C', true);
    $pdf->Cell(35, 10, 'Course',      1, 0, 'C', true);
    $pdf->Cell(35, 10, 'Time In',     1, 1, 'C', true);
}

// ── Table rows ────────────────────────────────────────────
$pdf->SetFont('Arial', '', 11);
$pdf->SetTextColor(0, 0, 0);
$pdf->SetFillColor(240, 240, 240);
$fill = false;
$i    = 1;

while ($row = $result->fetch_assoc()) {
    if ($status === 'absent') {
        $pdf->Cell(15, 8, $i++,                             1, 0, 'C', $fill);
        $pdf->Cell(40, 8, $row['student_no'],               1, 0, 'C', $fill);
        $pdf->Cell(70, 8, utf8_decode($row['fullname']),    1, 0, 'L', $fill);
        $pdf->Cell(55, 8, $row['course'],                   1, 1, 'C', $fill);
    } else {
        $pdf->Cell(15, 8, $i++,                             1, 0, 'C', $fill);
        $pdf->Cell(35, 8, $row['student_no'],               1, 0, 'C', $fill);
        $pdf->Cell(60, 8, utf8_decode($row['name']),        1, 0, 'L', $fill);
        $pdf->Cell(35, 8, $row['course'],                   1, 0, 'C', $fill);
        $pdf->Cell(35, 8, date('h:i A', strtotime($row['time_in'])), 1, 1, 'C', $fill);
    }
    $fill = !$fill;
}

// ── Summary ───────────────────────────────────────────────
$pdf->Ln(5);
$pdf->SetFont('Arial', 'B', 12);
$label = $status === 'absent' ? 'Absent' : 'Present';
$pdf->Cell(0, 10, "Total {$label}: {$total_count}", 0, 1, 'R');

$pdf->AddSignature();
$pdf->Output('D', $filename);