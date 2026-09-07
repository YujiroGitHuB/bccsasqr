<?php
// ============================================================
//  api/v1/handlers/terms.php
//
//  POST /api/v1/terms/accept
//
//  Katumbas ng api/accept_terms.php, pero may sagot na kayang
//  ipakita ng app: kailan tinanggap at anong bersyon. Iisa ang
//  talaan (student_terms_tbl) — kung tumanggap na ang estudyante sa
//  browser, hindi na siya tatanungin ulit ng app, at ganoon din ang
//  kabaligtaran.
// ============================================================

function handle_terms_accept(mysqli $conn): void
{
    // Higher than the lookup limit: a student may legitimately accept
    // again after a version bump, but nobody needs to do it in bulk.
    api_rate_limit('terms', 10, 60);

    $body       = api_json_body();
    $student_no = students_clean_no((string) ($body['student_no'] ?? ''));

    // Must be a real student — the record is worthless against a
    // number nobody owns, and this endpoint would otherwise write a
    // row for anything posted at it.
    $student = students_require($conn, $student_no);

    // The version comes from the server, never from the client:
    // otherwise an app could claim acceptance of a version whose text
    // the student never saw.
    $version = TERMS_VERSION;
    $ip      = api_client_ip();

    // (student_no, terms_version) is UNIQUE — accepting twice just
    // refreshes the timestamp instead of stacking rows.
    $stmt = $conn->prepare("
        INSERT INTO student_terms_tbl (student_no, terms_version, accepted_at, ip_address)
        VALUES (?, ?, NOW(), ?)
        ON DUPLICATE KEY UPDATE accepted_at = NOW(), ip_address = VALUES(ip_address)
    ");
    $stmt->bind_param('sis', $student_no, $version, $ip);

    if (!$stmt->execute()) {
        $stmt->close();
        api_fail(500, 'accept_failed', 'Could not record your acceptance. Please try again.');
    }
    $stmt->close();

    // Read the state back rather than assuming it — this is the value
    // the next /qr call will be judged against.
    $terms = gen_terms_state($conn, $student_no);

    api_ok([
        'student_no' => $student_no,
        'terms'      => $terms,
        // Handed back so the app can go straight to generating
        // without a second round trip.
        'can_generate' => $terms['accepted'],
        'qr'           => $terms['accepted'] ? gen_qr_resource($student) : null,
    ], 201);
}
