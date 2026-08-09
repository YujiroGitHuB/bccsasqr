<?php
include("db_connect.php");
// Middleware to check if logged-in user is disabled
if (isset($_SESSION['user_id'])) {
    $user_id = $_SESSION['user_id'];
    $check_stmt = $conn->prepare("SELECT status FROM users WHERE id = ?");
    $check_stmt->bind_param("i", $user_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows > 0) {
        $user_data = $check_result->fetch_assoc();
        $status = !empty($user_data['status']) ? $user_data['status'] : 'active';

        if ($status === 'disabled') {
            session_destroy();
            $_SESSION = array();

            session_start();
            $_SESSION['alert'] = [
                'icon' => 'error',
                'title' => 'Account Disabled',
                'text' => 'Your account has been disabled by an administrator.',
                'position' => 'center'
            ];

            header("Location: ../index.php");
            exit;
        }
    }
}
