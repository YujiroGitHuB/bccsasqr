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

// Ang HMAC key ng attendance integrity (includes/attendance_integrity.php):
// pinipirmahan nito ang device cookie at binubuo ang code sa harapan ng
// klase. Iwanang blangko at gagawa ang sistema ng isa at itatago sa
// attendance_settings — gumagana iyon, pero nakikita ito ng sinumang
// nakakabasa ng database. Sa isang tunay na deployment, itakda ito rito.
//
// Ang pagpapalit nito ay nagpapawalang-bisa sa bawat device cookie at sa
// bawat bukas na room code. Walang mawawalang attendance; magsisimulang
// muli lamang ang pagkilala sa bawat telepono.
define('INTEGRITY_SECRET', '');   // hal. bin2hex(random_bytes(32))
