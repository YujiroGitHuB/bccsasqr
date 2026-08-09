<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $name = trim($_POST['name']);
    $email = trim($_POST['email']);
    $password = trim($_POST['password']);
    $faceDescriptor = trim($_POST['faceDescriptor'] ?? '');
    $faceEnabled = !empty($faceDescriptor) ? 1 : 0;

    if (!empty($name) && !empty($email) && !empty($password)) {
        // Check if email already exists
        $check = $conn->prepare("SELECT * FROM users WHERE email=?");
        $check->bind_param("s", $email);
        $check->execute();
        $result = $check->get_result();

        if ($result->num_rows > 0) {
            $_SESSION['alert'] = [
                'icon' => 'error',
                'title' => 'Email Already Exists',
                'text' => 'Please use a different email or login.',
                'position' => 'center',
            ];
        } else {
            // Hash password
            $hashedPassword = password_hash($password, PASSWORD_ARGON2ID);
            
            // Insert new user with face recognition data
            $stmt = $conn->prepare("INSERT INTO users (name, email, password, face_descriptor, face_enabled) VALUES (?, ?, ?, ?, ?)");
            $stmt->bind_param("ssssi", $name, $email, $hashedPassword, $faceDescriptor, $faceEnabled);

            if ($stmt->execute()) {
                $loginMethod = $faceEnabled ? 'password or face recognition' : 'password';
                $_SESSION['alert'] = [
                    'icon' => 'success',
                    'title' => 'Registration Successful!',
                    'text' => 'You can now login with your ' . $loginMethod . '.',
                    'position' => 'center',
                    'redirect' => '../bccsasqr/index.php'
                ];
            } else {
                $_SESSION['alert'] = [
                    'icon' => 'error',
                    'title' => 'Error',
                    'text' => 'Something went wrong, please try again.',
                    'position' => 'center'
                ];
            }

            $stmt->close();
        }

        $check->close();
    } else {
        $_SESSION['alert'] = [
            'icon' => 'info',
            'title' => 'Incomplete Fields',
            'text' => 'Please fill in all required fields.',
            'position' => 'center'
        ];
    }

    $conn->close();

    // Redirect back to registration page
    header("Location: ../reg.php");
    exit;
}
?>