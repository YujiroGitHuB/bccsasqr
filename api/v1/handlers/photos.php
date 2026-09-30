<?php
// ============================================================
//  api/v1/handlers/photos.php
//
//  The student's own photo, from the app — the same two steps as
//  the web page (student/StudentPhotoProfile.php):
//    1. POST /students/{no}/verify  — is this really you?
//    2. POST /students/{no}/photo   — save this picture as your face
//
//  Same check, same file, same row as student/student_photo_api.php:
//  uploads/photos/student_{id}.jpg and student_photos. The scanner,
//  the admin photo list and the tracker already read those, so a
//  photo saved here is on the scanner from the student's next scan.
//
//  Stateless on purpose. The web page keeps "verified" in its PHP
//  session for ten minutes; the app has no session to keep, so each
//  upload carries the last name again and is checked again.
// ============================================================

/** student_photo_api.php's limit. The app sends about 50 KB. */
const PHOTO_MAX_BYTES = 1024 * 1024;

/** Big enough to be a face on the scanner, small enough to be a photo. */
const PHOTO_MIN_SIDE = 96;
const PHOTO_MAX_SIDE = 4096;

/**
 * Upper-cased and single-spaced, so "dela  cruz " matches "DELA CRUZ".
 *
 * mb_ when it is there: the web page's strtoupper() leaves "ñ" alone,
 * so a student typing "Peña" never matched a record saved as "PEÑA".
 */
function photos_normalise_name(string $name): string
{
    // /u gives up (null) on bytes that are not UTF-8; such a name is
    // still a name — just one that will not match — not a missing one.
    $name = preg_replace('/\s+/u', ' ', trim($name))
        ?? preg_replace('/\s+/', ' ', trim($name));

    return function_exists('mb_strtoupper')
        ? mb_strtoupper($name, 'UTF-8')
        : strtoupper($name);
}

/** "DELA CRUZ, JUAN P." → "DELA CRUZ" — the web page's rule. */
function photos_last_name_of(string $fullname): string
{
    return photos_normalise_name(explode(',', $fullname)[0]);
}

/**
 * The record, but only for someone who knows its last name.
 *
 * A wrong number and a wrong name get the web page's one message, so
 * this endpoint says no more about who exists than the lookup does.
 *
 * Throttled per number, not per IP alone: a class uploading together
 * on the school Wi-Fi is one IP, and must not lock itself out.
 */
function photos_require_owner(mysqli $conn, string $raw_no, $raw_last): array
{
    $student_no = students_clean_no($raw_no);
    api_rate_limit('photo|' . $student_no, 10, 900);

    $last = photos_normalise_name(is_string($raw_last) ? $raw_last : '');
    if ($last === '') {
        api_fail(400, 'missing_last_name', 'Enter your last name as it appears on your school record.');
    }

    $student = gen_find_student($conn, $student_no);

    if (!$student || !hash_equals(photos_last_name_of((string) $student['fullname']), $last)) {
        api_fail(403, 'identity_mismatch', 'Incorrect student number or last name. Use the spelling on your school record.');
    }

    return $student;
}

/**
 * POST /api/v1/students/{student_no}/verify
 *
 * Step 1 of the web page. Answers with the same resource as
 * GET /students/{no} — record, photo, warnings — so the app reads
 * both with one parser.
 */
function handle_student_verify(mysqli $conn, string $raw_no): void
{
    $body    = api_json_body();
    $student = photos_require_owner($conn, $raw_no, $body['last_name'] ?? '');

    api_ok(gen_student_resource($conn, $student));
}

/**
 * POST /api/v1/students/{student_no}/photo
 *
 * multipart/form-data: `last_name`, and the picture as `photo`. A file
 * part rather than base64 in JSON — the web page moved to form data
 * after a host's firewall kept refusing long base64 bodies.
 */
function handle_student_photo(mysqli $conn, string $raw_no): void
{
    // Over post_max_size, PHP drops the whole body: no last name, no
    // file. Say what actually happened instead of "enter your name".
    if ((int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > 0 && !$_POST && !$_FILES) {
        api_fail(413, 'photo_too_large', 'That picture is too large. Please use a smaller one.');
    }

    $student = photos_require_owner($conn, $raw_no, $_POST['last_name'] ?? '');

    $file = $_FILES['photo'] ?? null;
    $error = is_array($file) ? (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) : UPLOAD_ERR_NO_FILE;

    if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
        api_fail(413, 'photo_too_large', 'That picture is too large. Please use a smaller one.');
    }
    if ($error !== UPLOAD_ERR_OK || !is_uploaded_file((string) $file['tmp_name'])) {
        api_fail(400, 'missing_photo', 'No photo was received. Please try again.');
    }

    $bytes = (string) file_get_contents($file['tmp_name']);
    $student['photo_path'] = photos_store($conn, (int) $student['id'], photos_clean($bytes));

    api_ok(gen_student_resource($conn, $student), 201);
}

/**
 * The picture, checked, and redrawn as a plain JPEG when GD is there.
 *
 * Redrawn from its pixels so nothing else rides along in the file —
 * not the phone's EXIF (its location, from a camera), not bytes that
 * only pretend to be a picture — and so a file named .jpg really is
 * one. Without GD it is kept as sent, as the web page keeps it.
 */
function photos_clean(string $bytes): string
{
    if (strlen($bytes) > PHOTO_MAX_BYTES) {
        api_fail(413, 'photo_too_large', 'That picture is too large (max 1 MB). Please use a smaller one.');
    }

    $info = strlen($bytes) >= 500 ? @getimagesizefromstring($bytes) : false;
    if ($info === false || !in_array($info[2], [IMAGETYPE_JPEG, IMAGETYPE_PNG, IMAGETYPE_WEBP], true)) {
        api_fail(415, 'invalid_photo', 'That file is not a photo. Use a JPG, PNG or WEBP picture.');
    }

    [$width, $height] = $info;
    if (min($width, $height) < PHOTO_MIN_SIDE || max($width, $height) > PHOTO_MAX_SIDE) {
        api_fail(422, 'invalid_photo', 'That picture is too small to show your face. Please take it again.');
    }

    if (!function_exists('imagecreatefromstring') || !function_exists('imagejpeg')) {
        return $bytes;
    }

    $image = @imagecreatefromstring($bytes);
    if ($image === false) {
        api_fail(415, 'invalid_photo', 'That picture could not be read. Please take it again.');
    }

    // imagejpeg() prints to the output buffer api_boot() opened; catch
    // it in one of our own rather than write a temporary file.
    ob_start();
    $ok    = imagejpeg($image, null, 88);
    $clean = (string) ob_get_clean();

    return $ok && $clean !== '' ? $clean : $bytes;
}

/**
 * Saves the picture as uploads/photos/student_{id}.jpg and points
 * student_photos at it — exactly where the web page puts it.
 */
function photos_store(mysqli $conn, int $student_id, string $bytes): string
{
    $dir  = __DIR__ . '/../../../uploads/photos/';
    $name = 'student_' . $student_id . '.jpg';

    if (!is_dir($dir) && !@mkdir($dir, 0755, true) && !is_dir($dir)) {
        api_fail(500, 'photo_save_failed', 'Your photo could not be saved. Please try again later.');
    }

    // Written beside the old photo and renamed over it: a scanner
    // reading it at that moment gets the old face or the new one,
    // never half a file.
    $tmp = $dir . $name . '.' . bin2hex(random_bytes(4)) . '.tmp';
    if (@file_put_contents($tmp, $bytes) === false || !@rename($tmp, $dir . $name)) {
        @unlink($tmp);
        api_fail(500, 'photo_save_failed', 'Your photo could not be saved. Please try again later.');
    }
    @chmod($dir . $name, 0644);
    clearstatcache(true, $dir . $name);

    // The web page once kept other formats under the same stem.
    foreach (['png', 'webp'] as $ext) {
        $old = $dir . 'student_' . $student_id . '.' . $ext;
        if (file_exists($old)) {
            @unlink($old);
        }
    }

    $path = 'uploads/photos/' . $name;
    $stmt = $conn->prepare("
        INSERT INTO student_photos (s_id, photo_path)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE
            photo_path = VALUES(photo_path),
            updated_at = NOW()
    ");
    $stmt->bind_param('is', $student_id, $path);
    $stmt->execute();
    $stmt->close();

    return $path;
}
