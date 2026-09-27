# BCC SASQR

One Android app, two people, chosen on the opening screen:

- **My QR Code** — the Flutter port of the web QR generator. A student types
  their student number, the app matches it against the verified enrolment
  list, and — once the terms are accepted — renders a QR code the attendance
  scanner reads.
- **My Attendance** — the web Attendance Tracker (`Tracker/view.php`). A
  student types their student number and sees how many times they were
  marked present, per subject, with every date and any late mark. The server
  reads the same rules as the web page (`includes/attendance_history.php`).
- **Attendance Scanner** — the web scanner (`Qrscanner/qrscanner.php`) for a
  phone. An instructor signs in with their web account, picks a subject and
  scans; the server applies the web scanner's own rules
  (`includes/scan_attendance.php`), and both fill the same Attendance List.
  After a sign-in with the password, the instructor can put the phone's own
  lock (fingerprint, face or PIN, via `local_auth`) in front of it — see
  `controllers/scanner_lock_controller.dart`. Signing out drops the lock with
  the sign-in.

## Architecture

Layered MVC. Dependencies point one way only: **View → Controller → Service →
Model**. Nothing below a layer knows about anything above it.

```
lib/
├── main.dart                    entry point, system UI setup
├── app.dart                     root widget; builds the dependency graph
│
├── models/                      data + the rules that belong to the data
│   ├── student_record.dart      a verified enrolment record
│   ├── terms_document.dart      the terms text as the server authored them
│   ├── qr_payload.dart          holds the string the SERVER issued for the QR
│   ├── attendance_history.dart  the tracker: subjects, days, late marks
│   └── scanner_models.dart      signed-in user, subjects, scans
│
├── services/                    I/O boundaries, behind interfaces
│   ├── student_repository.dart  the contract + InMemoryStudentRepository
│   ├── http_student_repository.dart   the /api/v1 client (generator + tracker)
│   ├── tracker_repository.dart  the tracker's contract + its demo version
│   ├── qr_export_service.dart   QrExportService  + ImageQrExportService
│   ├── scanner_repository.dart  the scanner's contract + its demo version
│   ├── http_scanner_repository.dart   /api/v1/auth and /scanner
│   ├── token_store.dart         the sign-in token, in the keystore
│   ├── scan_feedback.dart       beep + vibration after a scan
│   └── speech_service.dart      the voice, for both halves
│
├── controllers/                 all mutable state and every decision
│   ├── qr_generator_controller.dart
│   ├── tracker_controller.dart  port of Tracker/js/script.js
│   └── scanner_controller.dart  port of Qrscanner/js/scriptV3.js
│
├── views/                       layout only — no business rules
│   ├── home_page.dart           the opening screen: generator, tracker or scanner
│   ├── qr_generator_page.dart   the generator; owns its controller
│   ├── tracker_page.dart        the attendance tracker; owns its controller
│   ├── scanner/                 sign-in, scanner page, camera
│   └── widgets/                 composable, single-purpose pieces
│
└── core/                        cross-cutting concerns
    ├── config/                  AppConfig — the --dart-define values
    ├── theme/                   AppPalette (light + dark), AppTheme
    ├── constants/               AppStrings (all user-facing copy)
    └── utils/                   StudentNumber value object + input formatter
```

### Why it is split this way

- **`QrGeneratorController`** is a plain `ChangeNotifier`. It answers every
  question the UI asks (`canGenerate`, `primaryActionLabel`, `isVerified`), so
  widgets only render what they are told. The views subscribe with the built-in
  `ListenableBuilder` — no state-management package needed.
- **Services are `abstract interface class`es.** `HttpStudentRepository` talks
  to `/api/v1`; `InMemoryStudentRepository` ships demo data for offline work.
  Which one is used is decided in one line in `app.dart`, and tests inject their
  own doubles the same way.
- **The QR payload comes from the server, never from the app.** The attendance
  scanner tests the decoded text against `^\d{3}-\d{3,4}$`
  (`Qrscanner/js/scriptV3.js`) and refuses anything else, so what goes inside
  the code is not the app's decision to make. See `models/qr_payload.dart`.
- **`StudentNumber` is a value object**, not a `String`. Parsing and validation
  live in one place, so the form and the repository cannot disagree about what a
  well-formed number is.
- **`AppStrings` / `AppPalette` hold no logic**, which keeps copy edits and
  re-skins out of widget code. Widgets read colours as `context.colors.x` —
  from the theme, never a static — so switching Light and Dark repaints every
  widget, `const` ones included.

## Behaviour

| State | What the screen shows |
|---|---|
| Idle | Dashed empty panel, primary button reads **Verify First**, disabled |
| Typing | Lookup fires only when the number is complete, debounced 400 ms |
| Verifying | Spinner in the field, shimmer bars on the record rows |
| Verified | Fields fill in, green *Record verified* line, lock icons open |
| Not found / failed | Inline red message; the code stays locked |
| Terms accepted | Button becomes **Generate QR Code** |
| Generated | White printable card with the QR, name, number, course and section |
| Download | Exports a 3× PNG and opens the platform share sheet |

Changing the student number or withdrawing consent discards a generated code —
a QR always matches the record currently on screen.

## The scanner

| Step | What the app does |
|---|---|
| Sign in | Email and password of the web account → a token kept in the Android Keystore. It stays until **Sign out**, 60 days unused, the account is disabled, or the password changes. |
| Subject | Required, as on the web. The camera does not start until one is picked. |
| Late marking | The same per-subject switch as the web; amber while on. |
| Scan | ZXing with `tryInverted`, so the light-on-dark BCC QR and a photocopied dark-on-light one both read. ML Kit (`mobile_scanner`) cannot read an inverted code, which is why it is not used. |
| Result | Photo (or initials and an amber *no photo* warning), name, course and section, the server's time; beep, vibration and the name read aloud. |
| Refusals | The web scanner's own messages and dialogs — *already marked*, *not enrolled*, *photo required*, *not assigned*, *Invalid QR Code*. |
| List | Today's scans by this account, from the web and the app alike, with search. |

The screen is held on while the camera runs (`wakelock_plus`). The camera
permission is asked the first time the scanner's camera opens, never at
install; the microphone permission the camera plugin declares is removed in
`AndroidManifest.xml`.

`flutter_zxing` is pinned to 2.2.x: 2.3 and later need Dart 3.11. It builds
zxing-cpp with NDK 27.0.12077973, which Gradle downloads on the first build.

Signing out is behind the avatar in the scanner's header: it opens an account
sheet (name, email, role, Settings, **Sign out**), and signing out asks first.

## Settings

The gear on the opening screen, or the account sheet in the scanner. Kept on
the phone in shared preferences (`services/settings_store.dart`).

| Setting | Effect |
|---|---|
| Theme | System, Light or Dark. The light palette is the web's `:root` tokens (`assets/css/theme.css`); the splash stays dark in both, as the native launch screen does. |
| Sound / Vibration | The beep and the buzz after a scan (`DeviceScanFeedback`). |
| Voice | Every spoken line, scanner and generator (`ToggleableSpeechService`). |
| About | Version and build from the installed package, the server in use, and a link to the download page — the app is installed from there, not a store. |

Raise `version:` in `pubspec.yaml` with every APK: a phone only installs an
update whose build number (after the `+`) is higher than the one it has.

## Connecting to the PHP backend

The server side is `api/v1/` in the main project — already written, and reading
the same rules as the web generator page. Point the app at its root:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-host/bccsasqr/api/v1
```

Add `--dart-define=API_KEY=…` only if `MOBILE_API_KEY` is set in
`includes/config.php`. Endpoint documentation: `api/v1/README.md`.

`HttpStudentRepository` then replaces `InMemoryStudentRepository` — nothing else
in the app changes.

**Forget the flag and you ship demo mode.** `API_BASE_URL` is read through
`String.fromEnvironment`, a compile-time constant, so a build without it has no
address to call and silently falls back to the four bundled records. The app
now says so in a notice at the top of the screen, but only after it is
installed. In VS Code, pick a configuration from Run and Debug rather than the
plain Run button — `.vscode/launch.json` in the project root carries the flag.

### Host requirement

The host must answer requests that do not come from a browser. Free hosts
(InfinityFree among them) protect sites with a JavaScript cookie challenge:
a browser runs the script and retries, but a mobile app receives the HTML
challenge page instead of JSON and cannot proceed. Check yours before building:

```bash
bash backend/check_host.sh https://your-host/bccsasqr/api/v1
```

If it reports BLOCKED, move the API to a host that permits app traffic. The
Flutter side does not change — only `API_BASE_URL` does.

That is what happened here: InfinityFree blocked the app, and the project moved
to Hostinger, which passes. `check_host.sh` against
`https://lexondev.com/bccsasqr/api/v1` reports OK (checked 2026-09-25).

## Demo records

`019-464`, `025-1023`, `021-318`, `023-770`. The dash is inserted
automatically; type digits only.

The scanner's demo signs in with any email and password and keeps its scans
on the phone. The same four numbers scan; `023-770` has no photo on file.
In a web build, where the native decoder does not run, a text field stands in
for the camera.

These are what a build without `API_BASE_URL` reads. A real student number will
report "not found" against them — the yellow notice at the top of the screen
names the four that do work, so that state is never mistaken for a broken
API.

## Running

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
flutter test      # unit + widget tests, generator and scanner
flutter analyze
```

For a phone plugged in by USB, serve the project and forward the port first:

```bash
php -S 0.0.0.0:8000 -t <the bccsasqr folder>
adb reverse tcp:8000 tcp:8000        # re-run after every replug
```

Android 9+ refuses plain http://. The development hosts are allowed by
`android/app/src/debug/res/xml/network_security_config.xml`, which applies to
debug builds only — a release build still refuses cleartext, so the deployed
API must be HTTPS.

## Layout

The generator is a single responsive screen. Panels sit side by side at ≥ 760 px wide and stack
below that; the header chips wrap under the title at ≥ 560 px. Content is
capped at 1040 px and centred.
