<?php
session_start();
include __DIR__ . "/../includes/db_connect.php";

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = trim($_POST['email']);
    $password = trim($_POST['password']);

    if (!empty($email) && !empty($password)) {
        $sql = "SELECT * FROM users WHERE email = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            $user = $result->fetch_assoc();

            // CHECK IF ACCOUNT IS DISABLED (ADD THIS!)
            $user_status = !empty($user['status']) ? $user['status'] : 'active';
            
            if ($user_status === 'disabled') {
                $_SESSION['alert'] = [
                    'icon' => 'error',
                    'title' => 'Account Disabled',
                    'text' => 'Your account has been disabled. Please contact the administrator.',
                    'position' => 'center'
                ];
                header("Location: ../index.php");
                exit;
            }

            // Verify password
            if (password_verify($password, $user['password'])) {
                $_SESSION['user_id'] = $user['id'];
                $_SESSION['user_name'] = $user['name'];
                $_SESSION['role'] = $user['role'];
                // Used by the topbar. Null-safe: servers that have not
                // run migrations/2026-08-10_add_user_avatar.sql have no
                // `avatar` column yet.
                $_SESSION['user_avatar'] = $user['avatar'] ?? null;

                // UPDATE LAST LOGIN (OPTIONAL BUT RECOMMENDED)
                $update_login = $conn->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
                $update_login->bind_param("i", $user['id']);
                $update_login->execute();

                // Success alert (center)
                $_SESSION['alert'] = [
                    'icon' => 'success',
                    'title' => 'Welcome!',
                    'text' => 'Hi ' . $_SESSION['user_name'] . ', glad to see you back!',
                    'position' => 'center',
                    'redirect' => '../bccsasqr/pages/dashboard.php'
                ];

                header("Location: ../index.php");
                exit;
            } else {
                $_SESSION['alert'] = [
                    'icon' => 'error',
                    'title' => 'Incorrect Password',
                    'text' => 'Please try again.',
                    'position' => 'center'
                ];
                header("Location: ../index.php");
                exit;
            }
        } else {
            $_SESSION['alert'] = [
                'icon' => 'warning',
                'title' => 'No user found',
                'text' => 'Please check your email or register first.',
                'position' => 'center'
            ];
            header("Location: ../index.php");
            exit;
        }
    } else {
        $_SESSION['alert'] = [
            'icon' => 'info',
            'title' => 'Incomplete Fields',
            'text' => 'Please fill in both email and password.',
            'position' => 'center'
        ];
        header("Location: ../index.php");
        exit;
    }
}