<?php
// ============================================================
// Local secrets — gitignored, do NOT commit.
// See config.example.php for the template.
// ============================================================

// NOTE: The previous key was committed to git history and must be
// treated as compromised — rotate it at https://aistudio.google.com/apikey
define('GEMINI_API_KEY', 'AIzaSyDcoCnTIRiVNMCYPIbxpofTPskYHph5Hpo');
define('GEMINI_MODEL',   'gemini-2.5-flash-lite');

define('ALLOWED_ORIGIN', '*');

// Optional shared secret for the mobile API (api/v1). Leave empty and the
// API stays as open as the QR generator page itself — which is how the web
// works today. Set a long random string to require an `X-API-Key` header
// on every /api/v1 call, and ship the same string in the Flutter build.
define('MOBILE_API_KEY', '');
