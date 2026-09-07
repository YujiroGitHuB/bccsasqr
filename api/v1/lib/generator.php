<?php
// ============================================================
//  api/v1/lib/generator.php
//
//  The QR generator's rules, in one place, so the phone and the
//  browser cannot drift apart.
//
//  Ang bawat panuntunan dito ay may katapat na sa web:
//    - ang lock          → QRgenerator/QRcode.php
//    - ang paghahanap    → includes/fetch_students.php
//    - ang terms         → includes/terms.php, api/accept_terms.php
//    - ang larawan       → includes/photo_requirement.php
//    - ang laman ng QR   → QRgenerator/js/scriptv2.js
//
//  Kapag binago ang alinman sa mga iyon, dito rin ang dadaanan.
// ============================================================

require_once __DIR__ . '/../../../includes/terms.php';
require_once __DIR__ . '/../../../includes/photo_requirement.php';

/**
 * The accepted shape of a student number.
 *
 * NOTE for the owner: the web app currently disagrees with itself —
 * fetch_students.js validates \d{3}-\d{3,4} while scriptv2.js
 * validates \d{3}-\d{1,5}. The looser of the two is used here so the
 * API never rejects a student number the generator page would have
 * accepted; the database stays the real judge of who exists.
 */
const GEN_STUDENT_NO_PATTERN = '/^\d{3}-\d{1,5}$/';
const GEN_STUDENT_NO_EXAMPLE = '019-464';

/** Is the generator switched off in Settings? */
function gen_is_locked(mysqli $conn): bool
{
    $res = $conn->query("SELECT setting_value FROM lock_settings_tbl WHERE setting_key = 'page_locked' LIMIT 1");

    if (!$res || $res->num_rows === 0) {
        return false;
    }

    return $res->fetch_assoc()['setting_value'] === 'true';
}

/**
 * How the QR itself must be drawn.
 *
 * The client renders the code (qr_flutter on the phone, qrcodejs in
 * the browser) — but both must produce the SAME image, so the size,
 * the error-correction level and the two colors come from the server.
 * The values match QRgenerator/js/scriptv2.js exactly.
 *
 * `background` is also the card's background in the download: if the
 * two ever differ, a visible square seam appears around the code.
 */
function gen_qr_spec(): array
{
    return [
        'encodes'           => 'student_no',
        'size'              => 250,
        'error_correction'  => 'M',
        'foreground'        => '#38bdf8',
        'background'        => '#0f172a',
        'quiet_zone'        => 4,
    ];
}

/** One student row, or null. Mirrors includes/fetch_students.php. */
function gen_find_student(mysqli $conn, string $student_no): ?array
{
    $stmt = $conn->prepare("
        SELECT s.id, s.student_no, s.fullname, s.course, s.section, p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
        LIMIT 1
    ");
    $stmt->bind_param('s', $student_no);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return $row ?: null;
}

/**
 * Has this student accepted the CURRENT terms?
 *
 * Scoped to TERMS_VERSION on purpose: raising the version in
 * includes/terms.php is what makes every student see the terms again,
 * and the API has to honour that the same way the page does.
 */
function gen_terms_state(mysqli $conn, string $student_no): array
{
    $version = TERMS_VERSION;

    $stmt = $conn->prepare("
        SELECT accepted_at
        FROM student_terms_tbl
        WHERE student_no = ? AND terms_version = ?
        LIMIT 1
    ");
    $stmt->bind_param('si', $student_no, $version);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return [
        'version'     => $version,
        'accepted'    => (bool) $row,
        'accepted_at' => $row['accepted_at'] ?? null,
    ];
}

/**
 * The photo rule, reported but NOT enforced here.
 *
 * A missing photo does not stop a QR from being generated — on the
 * web it does not either. It stops the SCAN later
 * (crud/save_attendance.php, crud/verify_student.php via
 * includes/photo_requirement.php). Telling the app now lets it nudge
 * the student while they still have the screen open, instead of
 * letting them find out in front of the class.
 */
function gen_photo_state(mysqli $conn, array $student): array
{
    $required = photo_is_required($conn);
    $has      = !empty($student['photo_path']);

    return [
        'required'  => $required,
        'has_photo' => $has,
        'url'       => $has ? api_asset_url($student['photo_path']) : null,
        'blocks_attendance' => $required && !$has,
    ];
}

/**
 * Everything the app needs about one student, in the shape both
 * GET /students/{no} and GET /students/{no}/qr answer with.
 */
function gen_student_resource(mysqli $conn, array $student): array
{
    $student_no = $student['student_no'];
    $terms      = gen_terms_state($conn, $student_no);
    $photo      = gen_photo_state($conn, $student);

    $warnings = [];
    if ($photo['blocks_attendance']) {
        $warnings[] = [
            'code'    => 'photo_missing',
            'message' => photo_required_message(),
        ];
    }

    return [
        'student' => [
            'student_no' => $student_no,
            // The card prints these three verbatim; the browser
            // upper-cases course and section (scriptv2.js) and so
            // should the app.
            'fullname'   => $student['fullname'],
            'course'     => $student['course'],
            'section'    => $student['section'],
        ],
        'terms'        => $terms,
        'photo'        => $photo,
        'can_generate' => $terms['accepted'],
        'warnings'     => $warnings,
    ];
}

/**
 * The QR payload and the text printed under it.
 *
 * Only the student number is encoded — the scanner
 * (Qrscanner/js/scriptV3.js) looks the rest up from the database at
 * scan time, so putting a name inside the code would only create a
 * second copy that can go stale.
 */
function gen_qr_resource(array $student): array
{
    $upper = static fn(?string $v): string => strtoupper(trim((string) $v));

    return [
        'payload' => $student['student_no'],
        'spec'    => gen_qr_spec(),
        'card'    => [
            'filename' => 'QR-' . preg_replace('/[^A-Za-z0-9\-]/', '', $student['student_no']) . '.png',
            'details'  => [
                ['label' => 'Student No.', 'value' => trim((string) $student['student_no'])],
                ['label' => 'Name',        'value' => trim((string) $student['fullname'])],
                ['label' => 'Course',      'value' => $upper($student['course'])],
                ['label' => 'Section',     'value' => $upper($student['section'])],
            ],
        ],
    ];
}
