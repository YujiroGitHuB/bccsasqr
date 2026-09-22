<?php
// ============================================================
// Database login — COPY this file to `db_credentials.php` and fill in.
//
// db_credentials.php is gitignored AND excluded from the deploy
// (.github/workflows/deploy.yml), which is the point of it: the copy
// sitting on Hostinger holds the live database password and no push
// will ever overwrite it. Create it once there, by hand, and forget it.
//
// Without the file, includes/db_connect.php falls back to the XAMPP
// defaults below, so a fresh clone still runs locally with no setup.
//
// ── On Hostinger ────────────────────────────────────────────
// hPanel → Databases → Management lists the database name, its user
// and the host. On shared hosting the host stays 'localhost' — the
// database runs on the same machine as PHP, so there is no network
// round trip to pay for. Both the name and the user carry the
// account prefix (u123456789_...); type them exactly as hPanel shows
// them, prefix included.
// ============================================================

define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_NAME', 'bcc_qr_attendance_db');
