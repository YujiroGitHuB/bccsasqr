# QR Generator and Scanner API (v1)

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

None for the generator: students do not log in, exactly as on the web page.
The scanner endpoints are the exception — an instructor signs in, as on the
web scanner; see [Scanner endpoints](#scanner-endpoints-signed-in).

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
The live feed (`POST /students/{student_no}/live`) is counted per student
number as well, 30 a minute, so a class on one Wi-Fi does not share one
allowance.
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
  "student": { "student_no": "000-1023", "fullname": "Santos, Maria Isabel", "course": "BSCS", "section": "2B" },
  "terms":   { "version": 1, "accepted": false, "accepted_at": null },
  "photo":   { "required": false, "has_photo": false, "url": null, "blocks_attendance": false },
  "can_generate": false,
  "warnings": []
} }
```

`warnings` never blocks the QR. It lists things that will trip the student up
later, each with a message safe to show as-is and, when there is somewhere to
fix it, an `action` to offer as a button. Today there is one:

```json
{ "code": "photo_missing",
  "message": "You need to upload your photo before you can record attendance. …",
  "action": { "label": "Upload your photo",
              "url": "https://…/student/StudentPhotoProfile.php" } }
```

It appears when Settings → Student Photo Requirement is on and the student has
no photo — the scanner and the attendance link would refuse them. Render any
warning you receive, not just the codes you know about.

Errors: `invalid_student_no` (400), `student_not_found` (404).

### `POST /terms/accept`

Records the acceptance in `student_terms_tbl`, the same table and the same
`ON DUPLICATE KEY` behaviour as `api/accept_terms.php`. One record serves both
clients: a student who accepted in the browser is not asked again in the app.

```json
POST /api/v1/terms/accept
Content-Type: application/json

{ "student_no": "000-1023" }
```

`201` on success, and the QR payload comes back with it so you can go straight
to rendering:

```json
{ "success": true, "data": {
  "student_no": "000-1023",
  "terms": { "version": 1, "accepted": true, "accepted_at": "2026-09-07 09:21:09" },
  "can_generate": true,
  "qr": { "payload": "000-1023", "spec": { … }, "card": { … } }
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
    "payload": "000-1023",
    "spec": { "encodes": "student_no", "size": 250, "error_correction": "M",
              "foreground": "#38bdf8", "background": "#0f172a", "quiet_zone": 4 },
    "card": {
      "filename": "000-1023_qr.png",
      "details": [
        { "label": "Student No.", "value": "000-1023" },
        { "label": "Name",        "value": "Santos, Maria Isabel" },
        { "label": "Course",      "value": "BSCS" },
        { "label": "Section",     "value": "2B" }
      ]
    }
  }
} }
```

Errors: `generator_locked` (503), `invalid_student_no` (400),
`student_not_found` (404), `terms_not_accepted` (409 — call
`POST /terms/accept` first, then retry).

### `GET /students/{student_no}/attendance`

The Attendance Tracker (`Tracker/view.php`) as data: how many times the
student was marked present, in which subjects, and when. Public like the web
tracker — no sign-in — and closed by the same Settings lock. The lookup and
the grouping live in `includes/attendance_history.php`, which the web tracker
reads too, so the two cannot count differently.

```json
{ "success": true, "data": {
  "student": { "student_no": "000-1023", "fullname": "SANTOS, MARIA ISABEL",
               "course": "BSCS", "section": "2B", "photo_url": "https://…/uploads/photos/student_1.jpg" },
  "summary": { "total": 3, "subjects": 2, "last_attended": "2026-08-24" },
  "subjects": [
    { "subject": "Object Oriented Programming", "instructor": "Charles Nixon Cayading", "count": 2,
      "records": [ { "date": "2026-08-24", "time_in": "10:07:17 AM", "late": false },
                   { "date": "2026-08-17", "time_in": "11:59:50 AM", "late": false } ] }
  ]
} }
```

Subjects come in name order, each one's dates newest first. A student with no
scans yet is still a `200`, with `total: 0` and an empty `subjects` — the
record exists, it just has nothing in it. `photo_url` is `null` without a
photo; show initials.

Errors: `tracker_locked` (503), `invalid_student_no` (400),
`student_not_found` (404), `tracker_failed` (500 — offer a retry). Rate
limited like the lookup: 20 a minute per IP.

### `POST /students/{student_no}/verify`

Step 1 of the web's photo page (`student/StudentPhotoProfile.php`): the
student proves the record is theirs with the last name on it — the part of
`fullname` before the comma, any case.

```json
POST /api/v1/students/000-1023/verify
Content-Type: application/json

{ "last_name": "Santos" }
```

Answers with the same resource as `GET /students/{student_no}`, so one parser
reads both. `photo.url` carries `?v=<file time>`: a new photo keeps the old
file name, and the stamp is what makes a phone load the new face.

Errors: `missing_last_name` (400), `identity_mismatch` (403 — the same message
for a wrong number and a wrong name, as on the web), `invalid_student_no` (400).

### `POST /students/{student_no}/photo`

Step 2: saves the student's photo. `multipart/form-data`, not JSON:

| Field | Value |
|---|---|
| `last_name` | Checked again — the API keeps no session between the two steps. |
| `photo` | The picture as a file: JPG, PNG or WEBP, at most 1 MB, sides 96–4096 px. The app sends a 400 × 400 JPEG. |

It lands exactly where the web page puts it — `uploads/photos/student_{id}.jpg`
and the `student_photos` row — so the scanner shows it from the next scan.
With GD on the server the picture is redrawn as a plain JPEG, which drops the
phone's EXIF (location included). `201` with the updated resource.

Errors: as `/verify`, plus `missing_photo` (400), `photo_too_large` (413),
`invalid_photo` (415/422), `photo_save_failed` (500).

`/verify` and `/photo` share one limit: **10 per 15 minutes per student number
per IP** — per number, so a whole class uploading on the school Wi-Fi does not
lock itself out.

### `POST /students/{student_no}/live`

The app's live feed: what is new on the student's record since the phone last
looked. The app asks every 15 seconds while it is open (every 6 while the code
is up for the scanner), so a student is told "Marked present" the moment the
scan lands — no pull to refresh. Only what changed comes back; the whole
history stays with `/attendance`.

```json
POST /api/v1/students/000-1023/live
Content-Type: application/json

{ "last_name": "Santos", "since": 6950 }
```

```json
{ "success": true, "data": {
  "cursor": 6957, "count": 43, "more": false,
  "records": [
    { "id": 6957, "subject": "Object Oriented Programming", "instructor": "Sample Instructor",
      "date": "2026-10-01", "time_in": "08:04:12 AM", "late": false, "offline": false }
  ]
} }
```

`since` is the `cursor` of the previous answer. Leave it out on the phone's
first look: `records` is then empty — a phone set up today is not told about
every scan of the semester. `records` holds at most 25, newest first; `more`
says there were more. Records are never edited after they are written (the
late mark is stamped at the scan), only added or deleted, so a `count` lower
than the last one plus the new records means one was deleted — ask
`/attendance` again to see which. `offline` marks a scan the instructor's
phone kept with no signal and sent later; its time is when it was scanned.

The last name is the proof, as for `/verify` and Check in. Errors:
`missing_last_name` (400), `identity_mismatch` (403 — the same message for a
wrong number and a wrong name), `invalid_student_no` (400), `tracker_locked`
(503 — the tracker's Settings lock). Limited **30 a minute per student
number per IP** — per number, so a class on the school Wi-Fi does not slow
itself down.

---

## Scanner endpoints (signed in)

The app's attendance scanner — the web scanner (`Qrscanner/qrscanner.php`)
for a phone. Every rule it applies lives in `includes/scan_attendance.php`,
which the web endpoints (`crud/save_attendance.php`, `crud/get_attendance.php`,
`crud/set_scan_late.php`) call too, so the two scanners cannot drift apart.

### Signing in

```
POST /api/v1/auth/login
{ "email": "…", "password": "…", "device": "BCC SASQR app" }
```

The same `users` row, `password_verify` and Security Monitor entries as
`crud/login_process.php`. An account without the **QR scanner** permission is
refused here (`403 no_scanner_access`) rather than handed a token for a screen
that would refuse it. `201` on success:

```json
{ "success": true, "data": { "token": "64 hex characters",
  "user": { "id": 4, "name": "…", "email": "…", "role": "instructor", "avatar_url": null } } }
```

Send the token on every call below as `X-Auth-Token: <token>`
(`Authorization: Bearer <token>` also works, but shared hosts running PHP as
CGI often drop that header). Only a SHA-256 of it is stored, in
`api_tokens_tbl` (`includes/api_tokens.php`, created on first use). It stops
working when the app signs out (`POST /auth/logout`), after 60 days unused,
when the account is disabled, and when the password is changed — by the owner
in My Profile or by an admin. A dead token answers `401 unauthenticated`; the
app goes back to its sign-in screen.

`GET /auth/me` — who the token belongs to, plus `can_scan`. The `user` object,
here and wherever it comes back (`/auth/login`, `/scanner/subjects`), carries
`can_manage_links`: whether the account has **Manage attendance links**, which
decides whether the app shows its Links tab.

### Scanning

Every scanner call checks, in order: a live token, the **QR scanner**
permission (`403 forbidden`), and the Settings page lock
(`503 scanner_locked` — the lock that closes the web scanner closes the app's).

| Endpoint | Body | Answers |
|---|---|---|
| `GET /scanner/subjects` | — | `{user, date, subjects: [{code, name, late}]}` — admins every subject with an instructor, instructors their own |
| `POST /scanner/scan` | `{student_no, subject_code}` | `201 {record: {student_no, name, course, section, subject, date, time_in, late, photo_url, photo_missing}}` |
| `GET /scanner/attendance` | — | `{date, records: [{date, student_no, name, course, section, subject, time_in, late}]}` — today, this account, newest first |
| `POST /scanner/late` | `{subject_code, on}` | `{subject_code, on}` — the switch the server settled on |
| `GET /scanner/roster?subject=CODE` | — | `{date, subject_code, photo_required, students: [{student_no, name, course, section, photo}]}` — one subject's class list, for scanning offline |
| `POST /scanner/sync` | `{scans: [{id, student_no, subject_code, scanned_at, late}]}` | `{results: [{id, status, …}]}` — scans kept on the phone while offline; see below |

`/scanner/scan`, `/scanner/roster` and `/scanner/sync` also need the
**Record attendance** permission. Who scanned, the date and the time come from
the token and the server's clock, never the request — except a scan sent from
the offline queue, below. Its refusals keep the web scanner's codes:

| HTTP | `code` | Meaning |
|---|---|---|
| 409 | `already_marked` | This student, this subject, today — already in |
| 403 | `not_authorized` | The subject is not assigned to this instructor |
| 404 | `student_not_found` | No such student number |
| 422 | `photo_required` | Photo requirement is on and none is on file; `details.name` |
| 422 | `not_enrolled` | Not enrolled in this subject |
| 400 | `missing_data` | No student number, or no such subject |
| 500 | `scan_failed` | Database error — logged, offer a retry |

### Scanning offline

The app keeps scanning with no internet. While it is online it downloads the
class list of each of the instructor's subjects (`/scanner/roster` — number,
name, course, section, and whether there is a photo; never the photo), so an
offline scan still names the student and still refuses one from another
class. The scan is kept on the phone and sent later, up to 50 at a time:

```
POST /api/v1/scanner/sync
{ "scans": [ { "id": "k3f9…", "student_no": "000-1023", "subject_code": "IT101",
               "scanned_at": "2026-09-30T00:25:54.120Z", "late": false } ] }
```

`scanned_at` is the phone's clock at the moment of the scan, as a full ISO
8601 instant; `late` is whether the late switch was on on the phone then. This
is the one place the server takes a time from the app, so it is limited
(`includes/offline_scan.php`): no later than now (10 minutes of clock drift
allowed), no more than 3 calendar days back. The row is stored with
`scanned_offline = 1` and `synced_at`, and the admin's Attendance Records show
it with an **Offline** tag.

Every scan goes through the same `scan_record()` on its own day and gets its
own answer, keyed by `id`:

| `status` | Meaning | The app |
|---|---|---|
| `saved` | Stored; `record` as `/scanner/scan` answers it | Drops it from the queue |
| `already_marked` | Already in — sent before and the answer was lost, or scanned on the web meanwhile | Drops it |
| `rejected` | Refused for good: `code` + `message` — the `/scanner/scan` codes, plus `bad_time` and `too_old` | Lists it under **Not saved** |
| `error` | The database failed on this one | Keeps it, sends it again |

Only what stops every scan fails the whole request — `401`, `403`, `503
scanner_locked`; the app keeps the lot and tries again. `400 too_many_scans`
above 50.

---

## Attendance links (signed in)

The web's Attendance Links page (`pages/generate_attendance_link.php`) for the
app's Links tab. Same token as the scanner; every call needs the **Manage
attendance links** permission (`403 forbidden` without it). Every rule —
which links exist, who may change one, what a time means — is in
`includes/links.php` and `includes/late.php`, which the page's own endpoints
(`pages/get_links_ajax.php`, `crud/set_link_*.php`, `crud/new_link_code.php`)
call too, so a change made on either side shows on the other at once.

| Endpoint | Body | Answers |
|---|---|---|
| `GET /links` | — | `{admin, links: [link…], rotated: [{old, new}]}` |
| `POST /links/expiry` | `{short_code}` + one of `minutes`, `preset: "eod"`, `at: "2026-09-30T17:00"`, `clear: true` | `{link}` |
| `POST /links/late` | `{short_code}` + one of `minutes`, `at: "08:15"`, `clear: true` | `{link}` |
| `POST /links/renew` | `{short_code}` (optionally an expiry, as above) | `{old_code, link}` |

A link:

```json
{ "short_code": "K7M2QP",
  "url": "https://…/pages/daily_attendance.php?c=K7M2QP",
  "expiry": { "at": "2026-09-30 17:00:00", "label": "Sep 30, 2026 5:00 PM",
              "short": "5:00 PM", "in": 3600, "expired": false },
  "late":   { "on": true, "in": 600, "label": "8:15 AM" },
  "subject_code": "IT101", "subject_name": "Sample Subject", "section": "BSIT-2A",
  "instructor": "…", "mine": true }
```

`in` is seconds from the server's now, measured by the database clock — the app
counts down from it and never decides from the phone's clock whether a link is
open. `expiry.at` is `null` for a link that never closes; `late.on` is only true
for a cutoff set today (see `includes/late.php`). The change endpoints answer
the same object without the subject fields.

Opening the list does the upkeep, as opening the web page does (there is no
cron): a class with enrolled students gets a link, one whose class is empty is
deactivated, and one that expired on an earlier day is given a new code —
listed in `rotated`, so the app can say that the old addresses stopped
working. `renew` does the same on request; the new link has no expiry and no
late cutoff until they are set.

An admin sees every instructor's links (`admin: true`, `mine` marks their own)
and may change any of them; an instructor sees and changes only their own —
anyone else's answers `404 link_not_found`. A time the server will not take
(already past, out of range, malformed) answers `422 not_changed` with a
message safe to show as-is.

---

## Checking in through a link (no sign-in)

The student's side of a link: the app's **Check in** reads the class QR (or
the six-letter code under it) and records the student this phone was set up
for in My Profile. Every rule is the web form's — `includes/link_checkin.php`
is shared with `crud/submit_attendance.php` — plus the last name, which the web
form cannot ask for.

| Endpoint | Body | Answers |
|---|---|---|
| `GET /checkin/{code}` | — | `{short_code, subject: {code, name}, section, instructor, closes: {label, in}, late: {on, label, in}}` |
| `POST /checkin/{code}` | `{student_no, last_name, device}` | `{subject, time_in, late, message, device}` |

`device` is the token a previous answer handed this phone — the app's
counterpart of the web form's signed `bcc_did` cookie — or nothing the first
time. Every answer, refusals included (in `error.details.device`), carries the
token to keep, so one phone stays one device for the one-device-one-student
rule. Refusals use the web form's words: `404 link_not_found`, `410 link_off`,
`410 link_expired`, `503 form_locked`, `403 photo_required`,
`403 not_enrolled`, `409 device_reuse`, `409 already_checked_in`,
`403 identity_mismatch` (the last name no longer matches the record). Each
attempt is written to `attendance_audit_tbl`, as the web form's are.

---

## Error codes

| HTTP | `code` | What the app should do |
|---|---|---|
| 400 | `missing_student_no` | Ask for the number. |
| 400 | `invalid_student_no` | Show the hint from `details.example`. |
| 400 | `invalid_body` | Bug in the client — the body was not JSON. |
| 400 | `missing_last_name` / `missing_photo` | Ask for the last name / pick the photo again. |
| 403 | `identity_mismatch` | Wrong number or last name — show `message`. |
| 413 | `photo_too_large` | Send a smaller picture. |
| 415 / 422 | `invalid_photo` | Not a usable picture — show `message`. |
| 500 | `photo_save_failed` | The server could not write the file — offer a retry. |
| 401 | `unauthorized` | The `X-API-Key` is missing or wrong. |
| 404 | `student_not_found` | "Check your Student Number." |
| 404 | `not_found` | Wrong URL — check the base URL form. |
| 405 | `method_not_allowed` | Wrong verb; `details.allowed` lists the right ones. |
| 409 | `terms_not_accepted` | Show the terms, POST the acceptance, retry. |
| 429 | `rate_limited` | Wait `details.retry_after` seconds. |
| 500 | `accept_failed` | Offer a retry. |
| 503 | `generator_locked` | Show the closed sign from `config.generator.message`. |
| 503 | `tracker_locked` | The same lock, reached from the tracker. |
| 500 | `tracker_failed` | Offer a retry. |
| 503 | `service_unavailable` | Server or database is down — offer a retry. |
| 401 | `unauthenticated` | Scanner token missing, expired or revoked — sign in again. |
| 401 | `invalid_credentials` | Wrong email or password. |
| 403 | `account_disabled` | The account is disabled. |
| 403 | `no_scanner_access` / `forbidden` | The account lacks the scanner (or record) permission. |
| 503 | `scanner_locked` | The QR pages are locked in Settings. |
| 404 | `link_not_found` | No such link, or not this account's to change. |
| 422 | `not_changed` | The time was refused; show `message`. |
| 500 | `links_failed` / `link_failed` | Database error — offer a retry. |

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

`card` is the rest of the saved image — the rows printed under the code and
the file name. The app's `lib/views/widgets/qr_card.dart` is a port of the web
page's `paintCard()` (`QRgenerator/js/scriptv2.js`) at the same coordinates, so
a card saved from the phone and one downloaded from the browser are the same
picture.

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
| Deployed (Hostinger)          | `https://lexondev.com/bccsasqr/api/v1` |

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
| `handlers/scanner.php` | `/auth/*`, `/scanner/*` |
| `handlers/tracker.php` | `/students/{no}/attendance` |
| `handlers/photos.php` | `POST /students/{no}/verify`, `POST /students/{no}/photo` |
| `handlers/links.php` | `/links`, `/links/*` |
| `lib/auth.php` | The scanner's token check and permissions |

## If you change the web page, change these

The API deliberately reads the same sources rather than copying them:

| Rule | Lives in | Read by |
|---|---|---|
| Page lock | `lock_settings_tbl` | `gen_is_locked()` |
| Student lookup | `students_tbl` | `gen_find_student()` |
| Terms text and version | `includes/terms.php` | `handle_terms()`, `gen_terms_state()` |
| Photo requirement | `includes/photo_requirement.php` | `gen_photo_state()` |
| Photo upload (last-name check, file, row) | `student/student_photo_api.php` | `handlers/photos.php` |
| QR colors and size | `QRgenerator/js/scriptv2.js` | `gen_qr_spec()` — **the one copy**; keep them in step |
| Attendance history | `includes/attendance_history.php` | `handle_student_attendance()` and `Tracker/crud/att_display.php` |
| Attendance links | `includes/links.php`, `includes/late.php` | `handlers/links.php` and the web page's endpoints |

One known inconsistency, inherited from the web app: `fetch_students.js`
validates `\d{3}-\d{3,4}` while `scriptv2.js` validates `\d{3}-\d{1,5}`. The API
uses the looser of the two so it never rejects a number the page would accept.
Worth making the three agree.
