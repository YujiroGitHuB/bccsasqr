# QR Generator API (v1)

A read-mostly REST API over the same rules as the web QR generator
(`QRgenerator/QRcode.php`), meant for the Flutter app. Everything the page
does — look up the student, show the terms, record the acceptance, hand over
what goes inside the QR — is here, and both clients read the rules from the
same PHP files so they cannot drift apart.

The Flutter app that consumes it lives in `bccsasqr-mobile/bccsasqr_app/`;
`lib/services/http_student_repository.dart` is the client for everything below.

---

## Base URL

Pick the first form that works on your host — all three reach the same router:

| Form | URL |
|---|---|
| Pretty (needs `mod_rewrite`; `.htaccess` is included) | `https://your-host/bccsasqr/api/v1/students/019-464` |
| `PATH_INFO` (no rewrite needed) | `https://your-host/bccsasqr/api/v1/index.php/students/019-464` |
| Query string (works everywhere, incl. InfinityFree) | `https://your-host/bccsasqr/api/v1/index.php?path=students/019-464` |

Local (XAMPP): `http://localhost/bccsasqr/api/v1/…`

> **Android emulator:** `localhost` is the emulator itself. Use
> `http://10.0.2.2/bccsasqr/api/v1`. On a real phone, use the PC's LAN IP and
> make sure XAMPP's Apache is reachable through the Windows firewall.
>
> **Android 9+ blocks plain HTTP.** Either serve over HTTPS or add a
> `network_security_config.xml` that allows your dev host.

## Authentication

None by default: students do not log in, exactly as on the web page.

To lock the API down (recommended if it is reachable from the public
internet), set a key in `includes/config.php`:

```php
define('MOBILE_API_KEY', 'some-long-random-string');
```

Every request must then carry it:

```
X-API-Key: some-long-random-string
```

Ship it in the app's build config, not in source control.

## Response shape

Every endpoint, success or failure, answers with the same envelope:

```json
{ "success": true,  "data":  { … } }
{ "success": false, "error": { "code": "…", "message": "…", "details": { … } } }
```

`message` is safe to show to a student as-is. `code` is what your Dart code
should branch on — it never changes wording.

## Rate limits

Per IP, per endpoint group: **20 lookups/minute**, **10 acceptances/minute**.
Over the limit you get `429` with a `Retry-After` header and
`details.retry_after` in seconds. Debounce the lookup in the app (the web page
waits 500 ms after the last keystroke) and you will never see it.

---

## Endpoints

### `GET /health`

Liveness, including the database — not just "PHP is running".

```json
{ "success": true, "data": { "status": "ok", "database": true,
  "version": "1.0.0", "server_time": "2026-09-07 09:20:59" } }
```

### `GET /config`

Call this once at app start. Everything here is admin-editable in Settings, so
reading it at runtime means a school can rename itself, change its logo or
close the generator without you shipping a new build.

```json
{ "success": true, "data": {
  "system":    { "name": "…", "acronym": "BCC SASQR v1.0", "logo_url": "https://…/assets/images/logo.png" },
  "generator": { "locked": false, "message": null,
                 "student_no": { "pattern": "^\\d{3}-\\d{1,5}$", "example": "019-464", "hint": "Use YEAR-NUMBER, e.g. 019-464." } },
  "qr":        { "encodes": "student_no", "size": 250, "error_correction": "M",
                 "foreground": "#38bdf8", "background": "#0f172a", "quiet_zone": 4 },
  "terms":     { "version": 1, "required": true, "url": "https://…/api/v1/terms" },
  "photo":     { "required": false, "note": "…" },
  "footer":    { "org": "", "developer": "", "developer_url": "", "year": "2026" }
} }
```

`generator.locked` mirrors Settings → page lock. When it is `true` the web page
replaces itself with `includes/lock.php`; the app should show the same closed
sign rather than a form that cannot submit.

### `GET /terms`

The Terms and Conditions, straight from `includes/terms.php` — there is no
second copy to keep in step. `html` is the authored text; `text` is a
plain-text fallback if you would rather not render HTML.

```json
{ "success": true, "data": { "version": 1, "contact": "…", "html": "<h4>1. …", "text": "1. …" } }
```

### `GET /students/{student_no}`

The lookup behind the web page's *"Verified — your record was loaded."* Returns
the record plus everything still standing between the student and a QR, so one
call is enough to decide whether your Generate button opens.

```json
{ "success": true, "data": {
  "student": { "student_no": "025-571", "fullname": "Albarida, Jelshian .", "course": "BSIT", "section": "1I" },
  "terms":   { "version": 1, "accepted": false, "accepted_at": null },
  "photo":   { "required": false, "has_photo": false, "url": null, "blocks_attendance": false },
  "can_generate": false,
  "warnings": []
} }
```

Errors: `invalid_student_no` (400), `student_not_found` (404).

### `POST /terms/accept`

Records the acceptance in `student_terms_tbl`, the same table and the same
`ON DUPLICATE KEY` behaviour as `api/accept_terms.php`. One record serves both
clients: a student who accepted in the browser is not asked again in the app.

```json
POST /api/v1/terms/accept
Content-Type: application/json

{ "student_no": "025-571" }
```

`201` on success, and the QR payload comes back with it so you can go straight
to rendering:

```json
{ "success": true, "data": {
  "student_no": "025-571",
  "terms": { "version": 1, "accepted": true, "accepted_at": "2026-09-07 09:21:09" },
  "can_generate": true,
  "qr": { "payload": "025-571", "spec": { … }, "card": { … } }
} }
```

The version is decided by the server. A client cannot claim acceptance of a
version whose text the student never saw.

### `GET /students/{student_no}/qr`

What to encode, how to draw it, and what to print underneath.

```json
{ "success": true, "data": {
  "student": { … }, "terms": { … }, "photo": { … },
  "can_generate": true, "warnings": [],
  "qr": {
    "payload": "025-571",
    "spec": { "encodes": "student_no", "size": 250, "error_correction": "M",
              "foreground": "#38bdf8", "background": "#0f172a", "quiet_zone": 4 },
    "card": {
      "filename": "QR-025-571.png",
      "details": [
        { "label": "Student No.", "value": "025-571" },
        { "label": "Name",        "value": "Albarida, Jelshian ." },
        { "label": "Course",      "value": "BSIT" },
        { "label": "Section",     "value": "1I" }
      ]
    }
  }
} }
```

Errors: `generator_locked` (503), `invalid_student_no` (400),
`student_not_found` (404), `terms_not_accepted` (409 — call
`POST /terms/accept` first, then retry).

---

## Error codes

| HTTP | `code` | What the app should do |
|---|---|---|
| 400 | `missing_student_no` | Ask for the number. |
| 400 | `invalid_student_no` | Show the hint from `details.example`. |
| 400 | `invalid_body` | Bug in the client — the body was not JSON. |
| 401 | `unauthorized` | The `X-API-Key` is missing or wrong. |
| 404 | `student_not_found` | "Check your Student Number." |
| 404 | `not_found` | Wrong URL — check the base URL form. |
| 405 | `method_not_allowed` | Wrong verb; `details.allowed` lists the right ones. |
| 409 | `terms_not_accepted` | Show the terms, POST the acceptance, retry. |
| 429 | `rate_limited` | Wait `details.retry_after` seconds. |
| 500 | `accept_failed` | Offer a retry. |
| 503 | `generator_locked` | Show the closed sign from `config.generator.message`. |
| 503 | `service_unavailable` | Server or database is down — offer a retry. |

---

## Why the server does not return a PNG

The API hands over the **payload** and the **drawing spec**, not an image. The
client draws the code — `qr_flutter` on the phone, `qrcodejs` in the browser.

Three reasons:

1. The project has no Composer and no QR encoder in PHP. Adding one to render
   a picture the client can already draw is a dependency for nothing.
2. Rendering locally means the QR appears instantly and works offline once the
   student's record has been fetched — which matters on campus wifi.
3. The web page already does it this way (`QRgenerator/js/scriptv2.js`), so
   both clients produce the same code from the same rules.

Because `spec` comes from the server, the two images stay identical: same size,
same error-correction level, same colors. Use it rather than hardcoding.

**Only the student number is encoded.** The scanner looks up the name, course
and section from the database at scan time, so putting them inside the code
would only create a second copy that can go stale.

## Flutter setup

The app takes the API root at build time — nothing is hardcoded in the source:

```
flutter run   --dart-define=API_BASE_URL=http://10.0.2.2/bccsasqr/api/v1   --dart-define=API_KEY=only-if-MOBILE_API_KEY-is-set
```

| Where the app runs            | `API_BASE_URL`                       |
|-------------------------------|--------------------------------------|
| Android emulator → XAMPP      | `http://10.0.2.2/bccsasqr/api/v1`    |
| iOS simulator → XAMPP         | `http://localhost/bccsasqr/api/v1`   |
| Real phone on the same wifi   | `http://192.168.x.x/bccsasqr/api/v1` |
| Deployed                      | `https://your-host/bccsasqr/api/v1`  |

With no `API_BASE_URL` the app runs on bundled demo records, so it still starts
offline. If the host has no `mod_rewrite`, append `/index.php` to the value.

Android 9+ refuses plain `http://`, so local testing against XAMPP needs a
`network_security_config.xml` naming your dev host — HTTPS in production.

Which file does what in the app:

| File | Role |
|---|---|
| `lib/core/config/app_config.dart` | The dart-define values |
| `lib/services/http_student_repository.dart` | This API's client — routes, envelope, errors |
| `lib/services/student_repository.dart` | The contract, plus the offline demo implementation |
| `lib/models/qr_payload.dart` | Holds the server-issued payload (and why it must be server-issued) |
| `lib/controllers/qr_generator_controller.dart` | Lookup → terms → generate |

## Files

| File | Role |
|---|---|
| `index.php` | Router, CORS, key check, DB include |
| `lib/http.php` | Response envelope, path parsing, JSON body, API key |
| `lib/rate_limit.php` | Per-IP throttle (fails open) |
| `lib/generator.php` | The generator's rules, shared with the web page |
| `handlers/system.php` | `/health`, `/config`, `/terms` |
| `handlers/students.php` | `/students/{no}`, `/students/{no}/qr` |
| `handlers/terms.php` | `POST /terms/accept` |

## If you change the web page, change these

The API deliberately reads the same sources rather than copying them:

| Rule | Lives in | Read by |
|---|---|---|
| Page lock | `lock_settings_tbl` | `gen_is_locked()` |
| Student lookup | `students_tbl` | `gen_find_student()` |
| Terms text and version | `includes/terms.php` | `handle_terms()`, `gen_terms_state()` |
| Photo requirement | `includes/photo_requirement.php` | `gen_photo_state()` |
| QR colors and size | `QRgenerator/js/scriptv2.js` | `gen_qr_spec()` — **the one copy**; keep them in step |

One known inconsistency, inherited from the web app: `fetch_students.js`
validates `\d{3}-\d{3,4}` while `scriptv2.js` validates `\d{3}-\d{1,5}`. The API
uses the looser of the two so it never rejects a number the page would accept.
Worth making the three agree.
