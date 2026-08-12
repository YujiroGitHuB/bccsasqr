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

    // Get current logo from database
    $currentLogo = '';
    $result = $conn->query("SELECT logo FROM system_settings_tbl WHERE id=1");
    if ($row = $result->fetch_assoc()) {
        $currentLogo = $row['logo'];
    }

    // Default to current logo if no new file uploaded
    $logoPath = $currentLogo;

    // Handle logo upload
    if (isset($_FILES['systemLogo']) && $_FILES['systemLogo']['error'] === UPLOAD_ERR_OK) {

        // Validate that the upload is actually an image, and derive a SAFE
        // extension from its real type — never trust the client filename
        // (that would allow uploading logo.php → remote code execution).
        $allowed  = [
            IMAGETYPE_JPEG => 'jpg',
            IMAGETYPE_PNG  => 'png',
            IMAGETYPE_GIF  => 'gif',
            IMAGETYPE_WEBP => 'webp',
        ];
        $info = @getimagesize($_FILES['systemLogo']['tmp_name']);
        if ($info === false || !isset($allowed[$info[2]])) {
            echo json_encode(['success' => false, 'message' => 'Logo must be a JPG, PNG, GIF, or WEBP image.']);
            exit;
        }

        $ext         = $allowed[$info[2]];
        $newFileName = 'logo_' . time() . '.' . $ext;
        $destination = __DIR__ . '/../assets/images/' . $newFileName;

        // Delete old logo file if it exists
        if (!empty($currentLogo) && file_exists(__DIR__ . '/../' . $currentLogo)) {
            unlink(__DIR__ . '/../' . $currentLogo);
        }

        // Upload new logo file
        if (move_uploaded_file($_FILES['systemLogo']['tmp_name'], $destination)) {
            $logoPath = 'assets/images/' . $newFileName; // relative path for DB
        } else {
            $response = ['success' => false, 'message' => 'Failed to move uploaded file. Check folder permissions.'];
            echo json_encode($response);
            exit;
        }
    }

    // Update database
    $sql = "UPDATE system_settings_tbl
            SET system_name=?, system_acronym=?, logo=?,
                footer_org=?, footer_year=?, footer_developer=?, footer_developer_url=?
            WHERE id=1";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param(
        'sssssss',
        $systemName,
        $systemAcronym,
        $logoPath,
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
