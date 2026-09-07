<?php
// ============================================================
//  api/v1/handlers/students.php
//
//  Ang dalawang hakbang ng generator, isa-isa:
//    1. GET /students/{no}      — sino ito? (ang "Verified" ng web)
//    2. GET /students/{no}/qr   — ano ang ilalagay sa QR?
//
//  Magkahiwalay sila dahil magkahiwalay din sila sa screen: ang una
//  ay tumatakbo habang nagta-type pa ang estudyante, ang pangalawa ay
//  kapag pinindot na ang Generate.
// ============================================================

/**
 * Normalises and checks the shape of a student number before it ever
 * reaches a query.
 *
 * Whitespace is stripped rather than rejected: a phone keyboard adds
 * a trailing space on its own, and refusing "019-464 " would be the
 * app's fault showing up as the student's problem.
 */
function students_clean_no(string $raw): string
{
    $no = preg_replace('/\s+/', '', trim($raw));

    if ($no === '') {
        api_fail(400, 'missing_student_no', 'A student number is required.');
    }

    if (!preg_match(GEN_STUDENT_NO_PATTERN, $no)) {
        api_fail(400, 'invalid_student_no', 'Invalid format. Use YEAR-NUMBER, e.g. ' . GEN_STUDENT_NO_EXAMPLE . '.', [
            'pattern' => trim(GEN_STUDENT_NO_PATTERN, '/'),
            'example' => GEN_STUDENT_NO_EXAMPLE,
        ]);
    }

    return $no;
}

/** The row, or the 404 the app expects. */
function students_require(mysqli $conn, string $student_no): array
{
    $student = gen_find_student($conn, $student_no);

    if (!$student) {
        // The same wording as the generator page, so a student who
        // uses both is not told two different things.
        api_fail(404, 'student_not_found', 'Student not found. Please check your Student Number.');
    }

    return $student;
}

/**
 * GET /api/v1/students/{student_no}
 *
 * The lookup behind the "Verified — your record was loaded" state.
 * Answers with the record plus everything still standing between the
 * student and a QR, so the app can enable its Generate button from
 * one call.
 */
function handle_student(mysqli $conn, string $raw_no): void
{
    // Ten a minute is far more than a person typing one number, and
    // far less than a script walking through every possible one.
    api_rate_limit('lookup', 20, 60);

    $student_no = students_clean_no($raw_no);
    $student    = students_require($conn, $student_no);

    api_ok(gen_student_resource($conn, $student));
}

/**
 * GET /api/v1/students/{student_no}/qr
 *
 * What to encode, how to draw it, and what to print underneath.
 *
 * NOTE: the server does not render a PNG. The QR is drawn on the
 * client — qr_flutter on the phone, qrcodejs in the browser — which
 * is why the drawing spec travels with the payload. See the README
 * for the reason and for the widget that consumes this.
 */
function handle_student_qr(mysqli $conn, string $raw_no): void
{
    api_rate_limit('qr', 20, 60);

    // Checked first: when the generator is locked, nothing may come
    // out of it, and saying so before the lookup avoids confirming
    // whether a student number exists while the page is closed.
    if (gen_is_locked($conn)) {
        api_fail(503, 'generator_locked', 'The QR generator is temporarily closed. Please try again later.');
    }

    $student_no = students_clean_no($raw_no);
    $student    = students_require($conn, $student_no);
    $resource   = gen_student_resource($conn, $student);

    // The browser gates Generate behind the terms checkbox
    // (QRgenerator/js/terms.js). The API gates it behind the recorded
    // acceptance instead — a stricter door on purpose, because an
    // app's checkbox is not something this server ever sees.
    if (!$resource['terms']['accepted']) {
        api_fail(409, 'terms_not_accepted', 'You must accept the Terms and Conditions before generating a QR code.', [
            'terms_version' => TERMS_VERSION,
            'terms_url'     => api_base_url() . '/api/v1/terms',
            'accept_url'    => api_base_url() . '/api/v1/terms/accept',
        ]);
    }

    api_ok($resource + ['qr' => gen_qr_resource($student)]);
}
