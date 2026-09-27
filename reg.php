<?php
// ============================================================
// Public registration is closed.
//
// This page used to let anyone create an account, and every account
// it made was an active instructor with no admin in the loop — so
// anyone who found the URL could sign in to the web system and to the
// phone app's scanner. Accounts are created by an admin in Manage
// Users now (crud/save_user.php), and an instructor adds face sign-in
// afterwards in My Profile.
//
// The file stays so an old bookmark lands on the sign-in page with a
// sentence, rather than on a 404.
// ============================================================
session_start();

$_SESSION['alert'] = [
    'icon'     => 'info',
    'title'    => 'Registration is closed',
    'text'     => 'Accounts are created by the administrator. Please ask them to create one for you.',
    'position' => 'center',
];

header('Location: index.php');
exit;
