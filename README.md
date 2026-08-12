# BCC SASQR — Student Attendance System with QR Codes

A QR-code + face-recognition student attendance system built for **Binalatongan Community College**
(San Carlos City, Pangasinan).

Instructors and admins generate a QR code per student, scan those codes per subject to log attendance,
and view or export attendance and absence reports as PDF.

Built with **vanilla PHP** (procedural, MySQLi) and **Bootstrap 5** — no framework, no build step,
no package manager.

---

## Features

**Attendance**
- **QR scanning** — camera-based scanner ([Qrscanner/qrscanner.php](bccsasqr/Qrscanner/qrscanner.php)) using jsQR, with flashlight support. Logs `time_in` against the selected subject.
- **Shareable attendance links** — instructors generate a short-code link (`pages/daily_attendance.php?c=<code>`) that students open to self-record attendance for one subject/section. Links can expire or be deactivated.
- **Attendance form lock** — admin can freeze all self-service submissions (`attendance_settings.form_locked`).
- **Manual entry & bulk upload** — attendance can be typed in or uploaded from a file.
- **Student tracker** — public page ([Tracker/view.php](bccsasqr/Tracker/view.php)) where a student looks up their own attendance history.

**Students**
- Add, edit, delete students individually or in bulk.
- **CSV / tab-separated import** with a downloadable template ([crud/import_students.php](bccsasqr/crud/import_students.php)).
- **Student photo profiles** — students verify their identity and upload a photo ([student/StudentPhotoProfile.php](bccsasqr/student/StudentPhotoProfile.php)); admins/instructors browse them with search, pagination, and zoom.
- Per-student subject enrollment (`student_subjects_tbl`).

**QR codes**
- **Generator** ([QRgenerator/QRcode.php](bccsasqr/QRgenerator/QRcode.php)) — renders printable QR codes from student records via `qrcodejs`.

**Reports & dashboard**
- Dashboard with attendance statistics filtered by date, section, and subject.
- **PDF exports** via vendored FPDF: attendance reports ([exports/export_pdf.php](bccsasqr/exports/export_pdf.php)) and absence reports ([exports/export_absences_pdf.php](bccsasqr/exports/export_absences_pdf.php)).

**Administration**
- **Roles** — `admin` (sees everything) and `instructor` (sees only assigned subjects/sections).
- Assign subjects to instructors (`subject_instructors_tbl`) and sections to instructors (`instructor_section_tbl`), individually or in bulk.
- User management: create accounts, enable/disable them (disabled users are logged out on their next request).
- **DB-driven branding** — system name, acronym, and logo live in `system_settings_tbl` and are editable in Settings.
- **Page lock** — takes all public tools (registration, QR generator, scanner, tracker) offline behind a lock screen.
- **Database backups** ([pages/backup.php](bccsasqr/pages/backup.php)) — generates SQL dumps into `backups/`, keeping the 30 most recent.
- **DB monitor** — per-table sizes and row counts.

**Authentication**
- Email + password login with `password_verify`.
- **Face login / registration** using `face-api.js`. The submitted 128-float descriptor is re-verified **server-side** (Euclidean distance < 0.5) in [crud/face_login_process.php](bccsasqr/crud/face_login_process.php) — the client's match alone is never trusted.

**AI assistant**
- A Gemini-backed helper widget, proxied server-side through [api/gemini-proxy.php](bccsasqr/api/gemini-proxy.php) so the API key never reaches the browser.

---

## Requirements

- PHP 7.4+ with `mysqli`, `curl`, and `gd` (or at least the `getimagesize*` functions)
- MySQL / MariaDB
- Apache — XAMPP or WAMP is the assumed stack
- A modern browser with camera access for QR scanning and face login (browsers require **HTTPS or `localhost`** for camera permission)

There is no `composer install` / `npm install` step. FPDF is vendored in [includes/fpdf/](bccsasqr/includes/fpdf/); everything else (Bootstrap 5.3.2, Bootstrap Icons, SweetAlert2, DataTables, face-api.js, jsQR, qrcodejs, particles.js) loads from CDN — so the app needs an internet connection to render properly.

---

## Setup

**1. Put the project in your web root**

Copy or clone the `BCC_QR/` folder into `htdocs/` (XAMPP) or `www/` (WAMP).

**2. Create the database**

Create a schema named `bcc_qr_attendance_db`, then import the most recent dump from
[bccsasqr/backups/](bccsasqr/backups/) (e.g. `backup_2026-03-16_22-07-57.sql`) via phpMyAdmin or:

```bash
mysql -u root bcc_qr_attendance_db < bccsasqr/backups/backup_2026-03-16_22-07-57.sql
```

Those dumps double as the schema reference — there is no migrations folder.

**3. Check the DB connection**

Credentials are hardcoded in [bccsasqr/includes/db_connect.php](bccsasqr/includes/db_connect.php)
(`localhost` / `root` / empty password / `utf8mb4`). Edit that file if your MySQL differs.

**4. Add local secrets**

```bash
cp bccsasqr/includes/config.example.php bccsasqr/includes/config.php
```

Then fill in `GEMINI_API_KEY` (from https://aistudio.google.com/apikey), `GEMINI_MODEL`, and
`ALLOWED_ORIGIN`. `config.php` is gitignored. The AI assistant will not work until this exists.

**5. Make sure uploads are writable**

`bccsasqr/uploads/photos/` (student photos) and `bccsasqr/backups/` (SQL dumps) must be writable by the web server.

**6. Open the app**

| Page | URL |
| --- | --- |
| Login | `http://localhost/BCC_QR/bccsasqr/index.php` |
| Register an account | `http://localhost/BCC_QR/bccsasqr/reg.php` |
| QR generator | `http://localhost/BCC_QR/bccsasqr/QRgenerator/QRcode.php` |
| QR scanner | `http://localhost/BCC_QR/bccsasqr/Qrscanner/qrscanner.php` |
| Student tracker | `http://localhost/BCC_QR/bccsasqr/Tracker/view.php` |

The repo-root [index.php](index.php) is only a 404 splash that links to the login page.

---

## Project structure

```
BCC_QR/
├── index.php               # 404 splash → links to the login page
└── bccsasqr/               # the application
    ├── index.php           # login (password + face)
    ├── reg.php             # account registration
    ├── error.php           # friendly DB-failure page
    ├── pages/              # authenticated full-page views
    ├── crud/               # POST handlers (forms + AJAX) — redirect or echo JSON
    ├── api/                # JSON endpoints (absences data, student photos, Gemini proxy)
    ├── components/         # reusable partials — modals, sidebar, topbar, footer
    ├── includes/           # shared bootstrap (auth, permissions, db) + vendored FPDF
    ├── exports/            # FPDF report generators
    ├── assets/             # css/, js/ (one file per feature), images/
    ├── uploads/photos/     # student profile photos
    ├── backups/            # SQL dumps written by pages/backup.php
    ├── QRgenerator/        # standalone QR generator mini-app
    ├── Qrscanner/          # standalone QR scanner mini-app
    ├── Tracker/            # standalone student attendance tracker
    └── student/            # student photo profile self-service
```

Each top-level folder is a **role**, not a module. `QRgenerator/`, `Qrscanner/`, `Tracker/`, and
`student/` are standalone mini-apps with their own `css/` and `js/`, opened in a new tab from the
sidebar rather than embedded in the main flow.

---

## How it works

**No router.** Navigation is direct links to `.php` files. The sidebar
([components/sidebar.php](bccsasqr/components/sidebar.php)) highlights the active item via
`basename($_SERVER['PHP_SELF'])` and hides admin-only sections with `isAdmin()`.

**Page bootstrap.** Authenticated pages open with this include sequence — order matters, session first:

```php
session_start();
include "../includes/auth.php";              // redirect to login if not signed in
include "../includes/permissions.php";       // isAdmin() / isStaff()
include "../includes/check_user_status.php"; // log out disabled accounts
include "../includes/db_connect.php";        // provides $conn (mysqli)
```

**Roles.** `$_SESSION['role']` is either `admin` or `instructor` (note: `isStaff()` checks for the
string `'instructor'`). Instructors are scoped to their assignments in `subject_instructors_tbl` and
`instructor_section_tbl`.

**Alerts.** User-facing messages go through `$_SESSION['alert']` (`icon` / `title` / `text` /
`position`, optional `redirect`) and are rendered by SweetAlert2 in `includes/alert.php` — not `echo`.

**Timezone.** Set per-page with `date_default_timezone_set('Asia/Manila')`.

### Key tables

`users`, `students_tbl`, `attendance_tbl`, `subjects_tbl`, `subject_instructors_tbl`,
`instructor_section_tbl`, `student_subjects_tbl`, `attendance_links_tbl`, `attendance_settings`,
`lock_settings_tbl`, `system_settings_tbl`, `activity_log`.

### Data-model quirk: course + section

`students_tbl` and `attendance_tbl` store **`course` and `section` as separate columns**
(`course = "BSIT"`, `section = "1A"`), but the UI's notion of a "section" is the concatenation
`"BSIT-1A"`. Queries across the dashboard and reports therefore use `CONCAT(course, '-', section)`.

When touching section filtering or joining `students_tbl` ↔ `attendance_tbl`, join on **both**
`course` **and** `section`, and split a full section string back on `-` (year level is the leading
digit of the section part). [pages/dashboard.php](bccsasqr/pages/dashboard.php) is the canonical
reference and is heavily commented on exactly this.

---

## Security notes

Read these before deploying anywhere beyond a local machine.

- **Rotate the Gemini key.** It was moved out of `gemini-proxy.php` into gitignored `config.php`, but the old key **remains in git history** and must be rotated at https://aistudio.google.com/apikey.
- **DB credentials are hardcoded** (`root`, no password) in `db_connect.php`. Fine for local XAMPP, not for deployment.
- **SQL safety is inconsistent.** Most code uses prepared statements; some older code interpolates values or wraps them in `real_escape_string`. Prefer prepared statements for anything new and never widen the interpolation pattern.
- **Mutating endpoints must guard access** — `isAdmin()` for admin actions, an `empty($_SESSION['user_id'])` check otherwise.
- **Uploads** validate the real image type with `getimagesize()`/`getimagesizefromstring()` and derive the extension from the *detected* type, never the client filename (that previously allowed uploading `.php`). [student/student_photo_api.php](bccsasqr/student/student_photo_api.php) shows the fuller pattern: CSRF token + rate limiting + type/size validation.
- **Face login residual risk** — `get_face_users.php` still ships all stored descriptors to the browser, so a stolen descriptor could be replayed. Liveness / challenge-response is the next hardening step.
- **Errors are silenced.** `error_reporting(0)` and `display_errors 0` are set in `db_connect.php`, so PHP errors never surface. When debugging, check `bccsasqr/includes/db_error.log` and the Apache error log.
- **The committed `backups/*.sql` dump contains real student and user data.** It is gitignored going forward but remains in git history.

---

## Contributing conventions

- Match the surrounding file. Comments in this codebase are often **Taglish** (Tagalog/English mix) — keep new comments consistent with the file you're editing.
- One JS file per feature in `assets/js/`, loaded via `<script>` tags at the bottom of the page.
- Bootstrap dark theme throughout (`data-bs-theme="dark"`).
- Don't edit [includes/fpdf/](bccsasqr/includes/fpdf/) — it's a vendored third-party library.
