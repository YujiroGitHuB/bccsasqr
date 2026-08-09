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
    $sql = "UPDATE system_settings_tbl SET system_name=?, system_acronym=?, logo=? WHERE id=1";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('sss', $systemName, $systemAcronym, $logoPath);

    if ($stmt->execute()) {
        $response = ['success' => true, 'message' => 'System configuration updated successfully!'];
    } else {
        $response = ['success' => false, 'message' => $stmt->error];
    }

    $stmt->close();
}

echo json_encode($response);
