<?php
include __DIR__ . "/../includes/db_connect.php";

// One query per request, however many times this is included. It is
// pulled in by header.php, headerQrGenerator.php, headerTracker.php
// AND components/footer.php — a page that has a header and a footer
// used to run this SELECT twice.
if (!isset($GLOBALS['__bcc_system'])) {
    $systemQuery = mysqli_query($conn, "SELECT * FROM system_settings_tbl WHERE id = 1");
    $GLOBALS['__bcc_system'] = ($systemQuery ? mysqli_fetch_assoc($systemQuery) : null) ?: [];
}
$system = $GLOBALS['__bcc_system'];

$systemName = $system['system_name'] ?? 'None';
$systemLogo = $system['logo'] ?? 'assets/images/default-logo.png';
$systemAcronym = $system['system_acronym'] ?? 'None';

// ─── Footer ──────────────────────────────────────────────────────
// Rendered by components/footer.php and reg.php. The `?? ''` keeps
// the pages working on a database where 2026-08-12_add_footer_settings.sql
// has not been run yet — the footer just comes out shorter instead
// of throwing.
$footerOrg = $system['footer_org'] ?? '';
$footerDeveloper = $system['footer_developer'] ?? '';
$footerDeveloperUrl = $system['footer_developer_url'] ?? '';

// Blank means "always show the current year". That is the default,
// because a hardcoded year is wrong from the next 1st of January
// onward and nobody remembers to come back and fix it.
$footerYear = trim($system['footer_year'] ?? '');
if ($footerYear === '') {
    $footerYear = date('Y');
}
?>
