<?php
// ============================================================
// Shared base class for the PDF reports.
//
// exports/export_pdf.php and exports/export_absences_pdf.php each
// carried their own near-identical Header(): the same two logos, the
// same rule, the same page numbering — with the school name spelled
// two different ways and one of them pointing at 'bcc logo.png'
// while the other pointed at 'bcc-logo.png'. Both are here now, once,
// and driven by system_settings_tbl.
//
// Layout: if an admin has uploaded a letterhead banner
// (system_settings_tbl.report_header) it is drawn full width. If not,
// the report falls back to the older two-logo layout — but takes the
// school name from footer_org rather than a string literal.
// ============================================================

require_once __DIR__ . '/fpdf/fpdf.php';

class ReportPDF extends FPDF
{
    // Left/right margin used across the whole report, in mm.
    const MARGIN = 10;

    private $orgName     = '';
    private $letterhead  = '';   // absolute path, or '' when not set
    private $logoLeft    = '';
    private $logoRight   = '';

    private $reportTitle = '';
    private $reportSub   = '';
    private $preparedBy  = '';

    /** @var array [ [width, label, align], ... ] */
    private $tableCols = [];

    // Set once the first data row has been drawn, so a page break
    // repeats the column headings. Before that, page 1 draws them
    // itself — after the stat cards, which must come first.
    private $tableStarted = false;

    // ─── Setup ───────────────────────────────────────────────────

    /**
     * Reads the branding out of system_settings_tbl. $system is the
     * row already fetched by includes/systemConfig.php.
     */
    public function loadBranding(array $system)
    {
        // footer_org, not system_name: system_name is "BCC Student
        // Attendance System Using QR", which is the name of the
        // software, not of the school issuing the report.
        $this->orgName = trim($system['footer_org'] ?? '') ?: 'Binalatongan Community College';

        $header = trim($system['report_header'] ?? '');
        if ($header !== '') {
            $path = __DIR__ . '/../' . $header;
            if (is_file($path)) {
                $this->letterhead = $path;
            }
        }

        foreach (['bcc-logo.png', 'bcc logo.png'] as $candidate) {
            $path = __DIR__ . '/../assets/images/' . $candidate;
            if (is_file($path)) { $this->logoLeft = $path; break; }
        }
        $right = __DIR__ . '/../assets/images/scc-logo.png';
        if (is_file($right)) $this->logoRight = $right;
    }

    public function setReportTitle($title, $subtitle = '')
    {
        $this->reportTitle = $title;
        $this->reportSub   = $subtitle;
    }

    public function setPreparedBy($name) { $this->preparedBy = $name; }

    /** @param array $cols [ [width, label, align], ... ] */
    public function setTableColumns(array $cols) { $this->tableCols = $cols; }

    // ─── Text ────────────────────────────────────────────────────

    /**
     * FPDF's core fonts are Latin-1 only, but the database is utf8mb4
     * and holds names like "CARIÑO, JANELLE B." utf8_decode() is
     * deprecated as of PHP 8.2 (this runs on 8.2), and the absence
     * report never called it at all — that name came out as mojibake.
     * //TRANSLIT keeps a readable character instead of dropping it.
     */
    public static function txt($value)
    {
        $value = (string) $value;
        $out = @iconv('UTF-8', 'windows-1252//TRANSLIT', $value);
        return $out === false ? $value : $out;
    }

    /**
     * Trims $value until it fits $maxWidth millimetres in the CURRENT
     * font, and returns it converted for output.
     *
     * Counting characters instead does not work: at Arial 9, "DELA
     * CRUZ, MARIA ANGELICA CONCEPCION T." is 36 characters but 71mm,
     * and Cell() neither wraps nor clips — it simply draws over the
     * next column. Call this after SetFont(), so bold rows are
     * measured as bold.
     */
    public function fit($value, $maxWidth)
    {
        $s     = self::txt($value);
        $limit = $maxWidth - (2 * $this->cMargin);   // FPDF's own cell padding

        if ($limit <= 0 || $this->GetStringWidth($s) <= $limit) {
            return $s;
        }

        // Single-byte after txt(), so substr is safe here.
        while ($s !== '' && $this->GetStringWidth($s . '.') > $limit) {
            $s = substr($s, 0, -1);
        }
        return $s . '.';
    }

    // ─── Page furniture ──────────────────────────────────────────

    function Header()
    {
        $pageW   = $this->GetPageWidth();
        $usableW = $pageW - (self::MARGIN * 2);

        if ($this->letterhead !== '') {
            // Height is derived from the real aspect ratio; passing 0
            // to FPDF would work too, but the Y position after the
            // image has to be known to place the title.
            $size = @getimagesize($this->letterhead);
            $h = ($size && $size[0] > 0) ? $usableW * ($size[1] / $size[0]) : 24;

            $this->Image($this->letterhead, self::MARGIN, 8, $usableW);
            $this->SetY(8 + $h + 3);
        } else {
            $logoW = 22; $logoH = 22; $topY = 8;

            if ($this->logoLeft !== '')  $this->Image($this->logoLeft,  self::MARGIN, $topY, $logoW, $logoH);
            if ($this->logoRight !== '') $this->Image($this->logoRight, $pageW - $logoW - self::MARGIN, $topY, $logoW, $logoH);

            $this->SetY($topY);
            $this->SetFont('Arial', 'B', 15);
            $this->SetTextColor(17, 24, 39);
            $this->Cell(0, 9, self::txt($this->orgName), 0, 1, 'C');

            $this->SetFont('Arial', '', 9);
            $this->SetTextColor(107, 114, 128);
            $this->Cell(0, 5, 'San Carlos City, Pangasinan', 0, 1, 'C');

            if ($this->GetY() < $topY + $logoH + 2) {
                $this->SetY($topY + $logoH + 2);
            }
            $this->Ln(2);
        }

        // ── Report title ─────────────────────────────────────────
        $this->SetTextColor(17, 24, 39);
        $this->SetFont('Arial', 'B', 13);
        $this->Cell(0, 7, self::txt(strtoupper($this->reportTitle)), 0, 1, 'C');

        if ($this->reportSub !== '') {
            $this->SetFont('Arial', '', 9.5);
            $this->SetTextColor(107, 114, 128);
            $this->Cell(0, 5, self::txt($this->reportSub), 0, 1, 'C');
        }

        $this->Ln(1.5);
        $this->SetDrawColor(31, 122, 60);   // the green of the letterhead rule
        $this->SetLineWidth(0.6);
        $this->Line(self::MARGIN, $this->GetY(), $pageW - self::MARGIN, $this->GetY());
        $this->SetLineWidth(0.2);
        $this->SetDrawColor(180, 180, 180);
        $this->Ln(4);

        $this->SetTextColor(0, 0, 0);

        // Repeat the column headings after a page break.
        if ($this->tableStarted) {
            $this->TableHead();
        }
    }

    function Footer()
    {
        $this->SetY(-14);
        $this->SetDrawColor(210, 210, 210);
        $this->Line(self::MARGIN, $this->GetY(), $this->GetPageWidth() - self::MARGIN, $this->GetY());

        $this->Ln(1);
        $this->SetFont('Arial', 'I', 7.5);
        $this->SetTextColor(120, 120, 120);

        $this->Cell(60, 6, self::txt('Generated ' . date('M d, Y g:i A')), 0, 0, 'L');
        $this->Cell(0, 6, 'Page ' . $this->PageNo() . ' of {nb}', 0, 0, 'R');
        $this->SetTextColor(0, 0, 0);
    }

    // ─── Building blocks ─────────────────────────────────────────

    /**
     * The "Subject / Section / Date" strip. Pairs render as
     * "LABEL  value" across up to $perRow columns.
     */
    public function MetaBar(array $pairs, $perRow = 3)
    {
        $usableW = $this->GetPageWidth() - (self::MARGIN * 2);
        $colW    = $usableW / $perRow;

        $this->SetFillColor(246, 248, 250);
        $this->SetDrawColor(225, 229, 234);

        $rows = array_chunk($pairs, $perRow, true);
        foreach ($rows as $row) {
            $startY = $this->GetY();
            $this->Rect(self::MARGIN, $startY, $usableW, 11, 'DF');

            $i = 0;
            foreach ($row as $label => $value) {
                $x = self::MARGIN + ($colW * $i);

                $this->SetXY($x + 3, $startY + 1.6);
                $this->SetFont('Arial', '', 6.8);
                $this->SetTextColor(130, 138, 148);
                $this->Cell($colW - 6, 3.4, self::txt(strtoupper($label)), 0, 0, 'L');

                $this->SetXY($x + 3, $startY + 5.2);
                $this->SetFont('Arial', 'B', 9.5);
                $this->SetTextColor(17, 24, 39);
                $this->Cell($colW - 6, 4.6, $this->fit($value, $colW - 6), 0, 0, 'L');

                $i++;
            }
            $this->SetY($startY + 11);
        }

        $this->SetTextColor(0, 0, 0);
        $this->Ln(4);
    }

    /**
     * A row of stat cards: ['Present' => ['24', 'ok'], ...] where the
     * second element is a tone — ok / warn / bad / plain.
     */
    public function StatCards(array $stats)
    {
        $n = count($stats);
        if ($n === 0) return;

        $usableW = $this->GetPageWidth() - (self::MARGIN * 2);
        $gap     = 3;
        $cardW   = ($usableW - ($gap * ($n - 1))) / $n;
        $cardH   = 17;
        $y       = $this->GetY();

        $tones = [
            'ok'    => [[236, 253, 245], [16, 185, 129], [6, 95, 70]],
            'warn'  => [[255, 251, 235], [245, 158, 11], [146, 64, 14]],
            'bad'   => [[254, 242, 242], [239, 68, 68],  [153, 27, 27]],
            'plain' => [[248, 250, 252], [203, 213, 225], [30, 41, 59]],
        ];

        $i = 0;
        foreach ($stats as $label => $spec) {
            $value = is_array($spec) ? ($spec[0] ?? '') : $spec;
            $tone  = is_array($spec) ? ($spec[1] ?? 'plain') : 'plain';
            [$bg, $line, $ink] = $tones[$tone] ?? $tones['plain'];

            $x = self::MARGIN + (($cardW + $gap) * $i);

            $this->SetFillColor($bg[0], $bg[1], $bg[2]);
            $this->SetDrawColor($line[0], $line[1], $line[2]);
            $this->Rect($x, $y, $cardW, $cardH, 'DF');

            // A thicker accent down the left edge — the only thing
            // separating one tone from another at a glance.
            $this->SetFillColor($line[0], $line[1], $line[2]);
            $this->Rect($x, $y, 1.2, $cardH, 'F');

            $this->SetXY($x + 3.5, $y + 2.4);
            $this->SetFont('Arial', '', 6.8);
            $this->SetTextColor(110, 118, 128);
            $this->Cell($cardW - 5, 3.4, self::txt(strtoupper($label)), 0, 0, 'L');

            $this->SetXY($x + 3.5, $y + 6.4);
            $this->SetFont('Arial', 'B', 15);
            $this->SetTextColor($ink[0], $ink[1], $ink[2]);
            $this->Cell($cardW - 5, 8, self::txt($value), 0, 0, 'L');

            $i++;
        }

        $this->SetY($y + $cardH);
        $this->SetTextColor(0, 0, 0);
        $this->SetDrawColor(180, 180, 180);
        $this->Ln(5);
    }

    /** A small left-aligned heading above a block. */
    public function BlockTitle($text)
    {
        $this->SetFont('Arial', 'B', 10);
        $this->SetTextColor(17, 24, 39);
        $this->Cell(0, 6, self::txt($text), 0, 1, 'L');
        $this->SetTextColor(0, 0, 0);
        $this->Ln(0.5);
    }

    /** Draws the column headings set by setTableColumns(). */
    public function TableHead()
    {
        if (!$this->tableCols) return;

        $this->SetFont('Arial', 'B', 8.5);
        $this->SetFillColor(31, 122, 60);
        $this->SetDrawColor(31, 122, 60);
        $this->SetTextColor(255, 255, 255);

        $last = count($this->tableCols) - 1;
        foreach ($this->tableCols as $i => $col) {
            $this->Cell($col[0], 8, self::txt($col[1]), 1, $i === $last ? 1 : 0, $col[2] ?? 'C', true);
        }

        $this->SetTextColor(0, 0, 0);
        $this->SetDrawColor(205, 205, 205);
    }

    /** Call once, right before the first data row is written. */
    public function BeginTableBody() { $this->tableStarted = true; }

    /** Call after the last data row so page breaks stop repeating it. */
    public function EndTableBody() { $this->tableStarted = false; }

    /** The "no rows" state, drawn inside the table's width. */
    public function EmptyRow($message)
    {
        $usableW = $this->GetPageWidth() - (self::MARGIN * 2);
        $this->SetFont('Arial', 'I', 9.5);
        $this->SetTextColor(120, 128, 138);
        $this->SetFillColor(250, 250, 251);
        $this->Cell($usableW, 14, self::txt($message), 1, 1, 'C', true);
        $this->SetTextColor(0, 0, 0);
    }

    public function AddSignature()
    {
        if ($this->preparedBy === '') return;

        // Keep the block off a page of its own.
        if ($this->GetY() > $this->GetPageHeight() - 45) {
            $this->AddPage();
        }

        $this->Ln(10);
        $this->SetFont('Arial', 'B', 10);
        $this->SetTextColor(17, 24, 39);
        $this->Cell(0, 5, self::txt($this->preparedBy), 0, 1, 'R');

        $this->SetDrawColor(120, 120, 120);
        $x2 = $this->GetPageWidth() - self::MARGIN;
        $this->Line($x2 - 65, $this->GetY(), $x2, $this->GetY());

        $this->Ln(1);
        $this->SetFont('Arial', '', 8);
        $this->SetTextColor(110, 118, 128);
        $this->Cell(0, 5, 'Prepared by', 0, 1, 'R');
        $this->SetTextColor(0, 0, 0);
    }
}
