<?php
if (!isset($_SESSION['user_id'])) {
    // Pages are left out: an expired session opening the dashboard is
    // ordinary. An endpoint under crud/, api/ or exports/ being called
    // without one is someone trying it directly — or a tab left open
    // past its session, which is why it is only marked low.
    if (preg_match('#/(crud|api|exports)/#', $_SERVER['SCRIPT_NAME'] ?? '')) {
        require_once __DIR__ . '/security_log.php';
        security_denied('sign-in');
    }
    header("Location: ../index.php");
    exit;
}
