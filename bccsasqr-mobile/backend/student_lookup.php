<?php
/**
 * ============================================================
 * SUPERSEDED — do not deploy this file.
 * ============================================================
 *
 * The app now talks to `api/v1/` in the main project, which is wired to the
 * real schema and shares its rules with the web generator page. This template
 * was written against a schema this system does not have:
 *
 *   here                  actual (see includes/fetch_students.php)
 *   ------------------    ---------------------------------------
 *   students              students_tbl
 *   student_number        student_no
 *   full_name             fullname
 *   verified              (no such column)
 *
 * Deploying it would also put a second copy of the database password in the
 * web root, and a second lookup endpoint to keep in step with the first.
 *
 * Kept only as a reference for what the app used to expect. Delete it once
 * you are happy with api/v1.
 */

/**
 * BCC SASQR — student lookup endpoint for the mobile app.
 *
 * Drop this in your existing PHP project (e.g. /api/student_lookup.php) and
 * point the Flutter app at it:
 *
 *   flutter build apk --dart-define=API_BASE_URL=https://your-domain/api \
 *                     --dart-define=API_KEY=the-same-secret-as-below
 *
 * Responses:
 *   200 {"found": true, "record": {...}}
 *   200 {"found": false}
 *   400 {"error": "..."}   malformed student number
 *   401 {"error": "..."}   bad or missing API key
 *   500 {"error": "..."}   server/database failure
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

// ---------------------------------------------------------------------------
// 1. Configuration — CHANGE THESE.
// ---------------------------------------------------------------------------
const API_KEY  = 'change-me-to-a-long-random-string';

const DB_HOST  = 'sqlXXX.infinityfree.com';  // from your hosting panel
const DB_NAME  = 'ifx_xxxxxxx_bccsasqr';
const DB_USER  = 'ifx_xxxxxxx';
const DB_PASS  = 'your-db-password';

// Map to YOUR existing table and column names.
const TABLE          = 'students';
const COL_NUMBER     = 'student_number';
const COL_NAME       = 'full_name';
const COL_COURSE     = 'course';
const COL_SECTION    = 'section';
const COL_VERIFIED   = 'verified';   // set to null if you have no such column

// ---------------------------------------------------------------------------
// 2. Auth — keeps the endpoint from being a public data dump.
// ---------------------------------------------------------------------------
$provided = $_SERVER['HTTP_X_API_KEY'] ?? '';
if (!hash_equals(API_KEY, $provided)) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// ---------------------------------------------------------------------------
// 3. Validate the student number before it reaches the database.
// ---------------------------------------------------------------------------
$studentNumber = trim($_GET['student_number'] ?? '');
if (!preg_match('/^\d{3}-\d{3,4}$/', $studentNumber)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid student number format']);
    exit;
}

// ---------------------------------------------------------------------------
// 4. Look it up.
// ---------------------------------------------------------------------------
try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );

    $sql = sprintf(
        'SELECT %s AS student_number, %s AS full_name, %s AS course, %s AS section%s
         FROM %s WHERE %s = :number LIMIT 1',
        COL_NUMBER, COL_NAME, COL_COURSE, COL_SECTION,
        COL_VERIFIED ? ', ' . COL_VERIFIED . ' AS verified' : '',
        TABLE, COL_NUMBER
    );

    $stmt = $pdo->prepare($sql);
    $stmt->execute([':number' => $studentNumber]);
    $row = $stmt->fetch();

    if ($row === false) {
        echo json_encode(['found' => false]);
        exit;
    }

    echo json_encode([
        'found'  => true,
        'record' => [
            'student_number' => (string) $row['student_number'],
            'full_name'      => (string) $row['full_name'],
            'course'         => (string) $row['course'],
            'section'        => (string) $row['section'],
            // The app only shows verified records.
            'verified'       => isset($row['verified'])
                ? (bool) $row['verified']
                : true,
        ],
    ]);
} catch (Throwable $e) {
    // Log the detail; never leak it to the client.
    error_log('[sasqr] lookup failed: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Lookup failed']);
}
