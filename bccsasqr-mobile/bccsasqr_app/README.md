# BCC SASQR Code Generator

Flutter port of the BCC SASQR attendance QR generator. A student types their
student number, the app matches it against the verified enrolment list, and —
once the terms are accepted — renders a QR code the attendance scanner reads.

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
│   └── qr_payload.dart          holds the string the SERVER issued for the QR
│
├── services/                    I/O boundaries, behind interfaces
│   ├── student_repository.dart  the contract + InMemoryStudentRepository
│   ├── http_student_repository.dart   the /api/v1 client
│   └── qr_export_service.dart   QrExportService  + ImageQrExportService
│
├── controllers/                 all mutable state and every decision
│   └── qr_generator_controller.dart
│
├── views/                       layout only — no business rules
│   ├── qr_generator_page.dart   the screen; owns controller lifecycle
│   └── widgets/                 composable, single-purpose pieces
│
└── core/                        cross-cutting concerns
    ├── config/                  AppConfig — the --dart-define values
    ├── theme/                   AppColors, AppTheme
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
- **`AppStrings` / `AppColors` hold no logic**, which keeps copy edits and
  re-skins out of widget code.

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

## Demo records

`019-464`, `025-1023`, `021-318`, `023-770`. The dash is inserted
automatically; type digits only.

These are what a build without `API_BASE_URL` reads. A real student number will
report "not found" against them — the yellow notice at the top of the screen
names the four that do work, so that state is never mistaken for a broken
API.

## Running

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
flutter test      # 44 unit + widget tests
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

Single responsive screen. Panels sit side by side at ≥ 760 px wide and stack
below that; the header chips wrap under the title at ≥ 560 px. Content is
capped at 1040 px and centred.
