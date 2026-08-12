<?php
session_start();
include __DIR__ . "/../includes/permissions.php";
include __DIR__ . "/../includes/db_connect.php";

header('Content-Type: application/json');

// Only admins may change system configuration.
if (!isAdmin()) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$response = ['success' => false, 'message' => 'Something went wrong.'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $systemName = $_POST['systemName'] ?? '';
    $systemAcronym = $_POST['systemAcronym'] ?? '';

    // ─── Footer ──────────────────────────────────────────────────
    $footerOrg          = trim($_POST['footerOrg'] ?? '');
    $footerYear         = trim($_POST['footerYear'] ?? '');
    $footerDeveloper    = trim($_POST['footerDeveloper'] ?? '');
    $footerDeveloperUrl = trim($_POST['footerDeveloperUrl'] ?? '');

    // The URL is rendered into an href on EVERY page of the site, so a
    // `javascript:` or `data:` value would be stored XSS that fires for
    // every visitor. Only http/https are accepted; blank is fine and
    // renders the developer name as plain text.
    if ($footerDeveloperUrl !== '') {
        $scheme = strtolower((string) parse_url($footerDeveloperUrl, PHP_URL_SCHEME));
        if (($scheme !== 'http' && $scheme !== 'https') || !filter_var($footerDeveloperUrl, FILTER_VALIDATE_URL)) {
            echo json_encode([
                'success' => false,
                'message' => 'Developer link must be a full http:// or https:// address, or left blank.'
            ]);
            exit;
        }
    }

    // The columns are varchar(255)/varchar(20); MySQL truncates
    // silently past that, so refuse rather than store something the
    // admin did not type.
    if (mb_strlen($footerOrg) > 255 || mb_strlen($footerDeveloper) > 255 || mb_strlen($footerDeveloperUrl) > 255) {
        echo json_encode(['success' => false, 'message' => 'Footer organization, developer, and link must be 255 characters or fewer.']);
        exit;
    }
    if (mb_strlen($footerYear) > 20) {
        echo json_encode(['success' => false, 'message' => 'Footer year must be 20 characters or fewer.']);
        exit;
    }

    // Get current image paths from database
    $currentLogo   = '';
    $currentHeader = '';
    $result = $conn->query("SELECT logo, report_header FROM system_settings_tbl WHERE id=1");
    if ($row = $result->fetch_assoc()) {
        $currentLogo   = $row['logo'] ?? '';
        $currentHeader = $row['report_header'] ?? '';
    }

    /**
     * Shared by the logo and the report letterhead — the same upload
     * was written out twice otherwise.
     *
     * Validates that the upload really is an image and derives a SAFE
     * extension from its real type; the client filename is never
     * trusted, because honouring it would allow logo.php → remote
     * code execution.
     *
     * Returns the new relative path, or $current when nothing was
     * uploaded. Exits with JSON on a bad file.
     */
    function handleImageUpload($field, $prefix, $current, $label, $maxBytes)
    {
        if (!isset($_FILES[$field]) || $_FILES[$field]['error'] === UPLOAD_ERR_NO_FILE) {
            return $current;
        }

        if ($_FILES[$field]['error'] !== UPLOAD_ERR_OK) {
            echo json_encode(['success' => false, 'message' => "$label upload failed. The file may be larger than the server allows."]);
            exit;
        }

        if ($_FILES[$field]['size'] > $maxBytes) {
            $mb = round($maxBytes / 1048576, 1);
            echo json_encode(['success' => false, 'message' => "$label must be {$mb} MB or smaller."]);
            exit;
        }

        $allowed = [
            IMAGETYPE_JPEG => 'jpg',
            IMAGETYPE_PNG  => 'png',
            IMAGETYPE_GIF  => 'gif',
            IMAGETYPE_WEBP => 'webp',
        ];
        $info = @getimagesize($_FILES[$field]['tmp_name']);
        if ($info === false || !isset($allowed[$info[2]])) {
            echo json_encode(['success' => false, 'message' => "$label must be a JPG, PNG, GIF, or WEBP image."]);
            exit;
        }

        $newFileName = $prefix . '_' . time() . '.' . $allowed[$info[2]];
        $destination = __DIR__ . '/../assets/images/' . $newFileName;

        if (!move_uploaded_file($_FILES[$field]['tmp_name'], $destination)) {
            echo json_encode(['success' => false, 'message' => 'Failed to move uploaded file. Check folder permissions.']);
            exit;
        }

        // Only delete the old file once the new one is safely in place.
        if (!empty($current) && is_file(__DIR__ . '/../' . $current)) {
            @unlink(__DIR__ . '/../' . $current);
        }

        return 'assets/images/' . $newFileName;
    }

    $logoPath   = handleImageUpload('systemLogo', 'logo', $currentLogo, 'Logo', 4 * 1048576);
    $headerPath = handleImageUpload('reportHeader', 'letterhead', $currentHeader, 'Report header', 4 * 1048576);

    // Clearing the letterhead sends the PDF reports back to the
    // two-logo layout, so it needs an explicit way out — there is no
    // "empty file" you can pick in a file input.
    if (!empty($_POST['removeReportHeader']) && $headerPath === $currentHeader) {
        if (!empty($currentHeader) && is_file(__DIR__ . '/../' . $currentHeader)) {
            @unlink(__DIR__ . '/../' . $currentHeader);
        }
        $headerPath = '';
    }

    // Update database
    $sql = "UPDATE system_settings_tbl
            SET system_name=?, system_acronym=?, logo=?, report_header=?,
                footer_org=?, footer_year=?, footer_developer=?, footer_developer_url=?
            WHERE id=1";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param(
        'ssssssss',
        $systemName,
        $systemAcronym,
        $logoPath,
        $headerPath,
        $footerOrg,
        $footerYear,
        $footerDeveloper,
        $footerDeveloperUrl
    );

    if ($stmt->execute()) {
        $response = ['success' => true, 'message' => 'System configuration updated successfully!'];
    } else {
        $response = ['success' => false, 'message' => $stmt->error];
    }

    $stmt->close();
}

echo json_encode($response);
