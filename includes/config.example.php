<?php
// ============================================================
// Local secrets — COPY this file to `config.php` and fill in.
// config.php is gitignored and must NEVER be committed.
// ============================================================

// Google Gemini API key (get one at https://aistudio.google.com/apikey)
define('GEMINI_API_KEY', 'YOUR_GEMINI_API_KEY_HERE');
define('GEMINI_MODEL',   'gemini-2.5-flash-lite');

// Optional: restrict which origin may call the AI proxy.
// Use your deployed origin (e.g. 'https://yourschool.edu') or '*' for local dev.
define('ALLOWED_ORIGIN', '*');

// Optional shared secret for the mobile API (api/v1). Leave empty and the
// API stays as open as the QR generator page itself — which is how the web
// works today. Set a long random string to require an `X-API-Key` header
// on every /api/v1 call, and ship the same string in the Flutter build.
define('MOBILE_API_KEY', '');   // e.g. 'YOUR_LONG_RANDOM_KEY_HERE'
