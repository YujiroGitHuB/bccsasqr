<?php
/**
 * Export Absences to PDF
 */

session_start();
require('../includes/fpdf/fpdf.php');
include __DIR__ . "/../includes/db_connect.php";

if (!isset($_SESSION['user_id'])) {
    header("Location: ../pages/index.php");
    exit;
}

$user_id      = $_SESSION['user_id'];
$role         = $_SESSION['role'];
$user_name    = $_SESSION['user_name'];

$full_section = isset($_POST['section'])      ? $_POST['section']      : '';
$min_absences = isset($_POST['min_absences']) ? (int)$_POST['min_absences'] : 3;

if (empty($full_section)) {
    $_SESSION['error_message'] = "Section is required";
    header("Location: ../pages/dashboard.php");
    exit;
}

// ✅ FIXED: split "BSIT-1A" → course="BSIT", section="1A"
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
// ✅ FIXED: attendance_tbl has separate course + section columns
if ($role === 'admin') {
    $stmt = $conn->prepare("
        SELECT COUNT(DISTINCT DATE(date)) as total_classes
        FROM attendance_tbl
        WHERE course = ? AND section = ?
    ");
    $stmt->bind_param("ss", $course, $section);
} else {
    $stmt = $conn->prepare("
        SELECT COUNT(DISTINCT DATE(date)) as total_classes
        FROM attendance_tbl
        WHERE course = ? AND section = ?
        $subjects_filter
    ");
    $stmt->bind_param("ss", $course, $section);
}
$stmt->execute();
$total_classes = (int)$stmt->get_result()->fetch_assoc()['total_classes'];

// ── Students with absences >= min_absences ────────────────
// ✅ FIXED: all WHERE clauses use course + section separately
//           students_tbl also uses course + section separately
if ($role === 'admin') {
    $students_query = "
        SELECT
            s.student_no,
            s.fullname,
            s.course,
            s.section,
            COALESCE(a.attended, 0)                          AS attended,
            $total_classes                                    AS total_classes,
            ($total_classes - COALESCE(a.attended, 0))       AS absences
        FROM students_tbl s
        LEFT JOIN (
            SELECT student_no, COUNT(DISTINCT DATE(date)) AS attended
            FROM attendance_tbl
            WHERE course = ? AND section = ?
            GROUP BY student_no
        ) a ON s.student_no = a.student_no
        WHERE s.course = ? AND s.section = ?
        HAVING absences >= ?
        ORDER BY absences DESC, s.fullname ASC
    ";
    $stmt = $conn->prepare($students_query);
    $stmt->bind_param("ssssi", $course, $section, $course, $section, $min_absences);
} else {
    $students_query = "
        SELECT
            s.student_no,
            s.fullname,
            s.course,
            s.section,
            COALESCE(a.attended, 0)                          AS attended,
            $total_classes                                    AS total_classes,
            ($total_classes - COALESCE(a.attended, 0))       AS absences
        FROM students_tbl s
        LEFT JOIN (
            SELECT student_no, COUNT(DISTINCT DATE(date)) AS attended
            FROM attendance_tbl
            WHERE course = ? AND section = ?
            $subjects_filter
            GROUP BY student_no
        ) a ON s.student_no = a.student_no
        WHERE s.course = ? AND s.section = ?
        HAVING absences >= ?
        ORDER BY absences DESC, s.fullname ASC
    ";
    $stmt = $conn->prepare($students_query);
    $stmt->bind_param("ssssi", $course, $section, $course, $section, $min_absences);
}

$stmt->execute();
$result = $stmt->get_result();

// ── PDF Class ─────────────────────────────────────────────
class PDF extends FPDF
{
    function Header()
    {
        global $full_section, $min_absences, $user_name, $total_classes;

        $logo_left  = __DIR__ . '/../assets/images/bcc-logo.png';
        $logo_right = __DIR__ . '/../assets/images/scc-logo.png';
        $logo_w = 22;
        $logo_h = 22;
        $top_y  = 8;

        if (file_exists($logo_left))  $this->Image($logo_left,  10, $top_y, $logo_w, $logo_h);
        if (file_exists($logo_right)) $this->Image($logo_right, $this->GetPageWidth() - $logo_w - 10, $top_y, $logo_w, $logo_h);

        $this->SetY($top_y);
        $this->SetFont('Arial', 'B', 14);
        $this->Cell(0, 8, 'BINALATONGAN COMMUNITY COLLEGE', 0, 1, 'C');

        $this->SetFont('Arial', 'B', 13);
        $this->Cell(0, 7, 'ABSENCE REPORT', 0, 1, 'C');

        $this->SetFont('Arial', 'B', 10);
        $this->Cell(0, 6, "Students with {$min_absences}+ Absences", 0, 1, 'C');

        $this->SetFont('Arial', '', 9);
        // ✅ FIXED: display full_section "BSIT-1A" not raw "1A"
        $this->Cell(0, 5, "Section: {$full_section} | Total Classes: {$total_classes}", 0, 1, 'C');

        if ($this->GetY() < $top_y + $logo_h + 2) {
            $this->SetY($top_y + $logo_h + 2);
        }

        $this->Ln(3);

        $this->SetFillColor(255, 243, 205);
        $this->SetDrawColor(255, 193, 7);
        $this->SetFont('Arial', '', 9);
        $this->MultiCell(0, 5, "Generated by: {$user_name}\nDate: " . date('F d, Y g:i A'), 1, 'L', true);

        $this->Ln(4);

        $this->SetFont('Arial', 'B', 10);
        $this->SetFillColor(52, 58, 64);
        $this->SetTextColor(255, 255, 255);

        $this->Cell(8,  8, '#',           1, 0, 'C', true);
        $this->Cell(30, 8, 'Student No.', 1, 0, 'C', true);
        $this->Cell(67, 8, 'Name',        1, 0, 'C', true);
        $this->Cell(23, 8, 'Course',      1, 0, 'C', true);
        $this->Cell(20, 8, 'Attended',    1, 0, 'C', true);
        $this->Cell(20, 8, 'Absences',    1, 0, 'C', true);
        $this->Cell(22, 8, 'Rate',        1, 1, 'C', true);

        $this->SetTextColor(0, 0, 0);
    }

    function Footer()
    {
        $this->SetY(-15);
        $this->SetFont('Arial', 'I', 8);
        $this->Cell(0, 10, 'Page ' . $this->PageNo(), 0, 0, 'C');
    }
}

$pdf = new PDF();
$pdf->AddPage();
$pdf->SetFont('Arial', '', 9);

$count              = 1;
$total_students     = 0;
$total_absences_sum = 0;

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $absences     = $row['absences'];
        $absence_rate = $total_classes > 0 ? round(($absences / $total_classes) * 100, 1) : 0;

        if ($count % 2 == 0) {
            $pdf->SetFillColor(248, 249, 250);
        } else {
            $pdf->SetFillColor(255, 255, 255);
        }

        if ($absences >= 5) {
            $pdf->SetTextColor(220, 38, 38);
            $pdf->SetFont('Arial', 'B', 9);
        } else {
            $pdf->SetTextColor(0, 0, 0);
            $pdf->SetFont('Arial', '', 9);
        }

        $pdf->Cell(8,  7, $count,                             1, 0, 'C', true);
        $pdf->Cell(30, 7, $row['student_no'],                 1, 0, 'L', true);
        $pdf->Cell(67, 7, substr($row['fullname'], 0, 35),    1, 0, 'L', true);
        // ✅ FIXED: display course from row (already stored separately)
        $pdf->Cell(23, 7, $row['course'],                     1, 0, 'C', true);
        $pdf->Cell(20, 7, $row['attended'],                   1, 0, 'C', true);
        $pdf->Cell(20, 7, $absences,                          1, 0, 'C', true);
        $pdf->Cell(22, 7, $absence_rate . '%',                1, 1, 'C', true);

        $count++;
        $total_students++;
        $total_absences_sum += $absences;
    }

    $pdf->Ln(5);
    $pdf->SetFont('Arial', 'B', 10);
    $pdf->SetTextColor(0, 0, 0);
    $pdf->Cell(0, 8, "Summary", 0, 1, 'L');

    $pdf->SetFont('Arial', '', 9);
    $pdf->Cell(0, 6, "Total Students with {$min_absences}+ Absences: {$total_students}", 0, 1);
    $avg_absences = $total_students > 0 ? round($total_absences_sum / $total_students, 1) : 0;
    $pdf->Cell(0, 6, "Average Absences: {$avg_absences}", 0, 1);
} else {
    $pdf->SetFont('Arial', 'I', 10);
    $pdf->Cell(0, 10, 'No students found with ' . $min_absences . '+ absences.', 0, 1, 'C');
}

// ✅ FIXED: filename uses full_section "BSIT-1A" not raw "1A"
$filename = "Absences_Report_Section_{$full_section}_" . date('Y-m-d') . ".pdf";
$pdf->Output('D', $filename);