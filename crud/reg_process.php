<?php
// ============================================================
// Public registration is closed — see reg.php.
//
// Nothing here creates an account any more. The form that posted to
// this file is gone, so a POST that still arrives was sent by hand;
// it is logged to the Security Monitor and turned away. Accounts are
// created in Manage Users (crud/save_user.php).
// ============================================================
session_start();
include __DIR__ . "/../includes/db_connect.php";
require_once __DIR__ . "/../includes/security_log.php";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    security_denied('registration');
}

$_SESSION['alert'] = [
    'icon'     => 'info',
    'title'    => 'Registration is closed',
    'text'     => 'Accounts are created by the administrator. Please ask them to create one for you.',
    'position' => 'center',
];

header("Location: ../index.php");
exit;
