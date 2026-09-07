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
│   └── qr_payload.dart          the versioned envelope encoded in the QR
│
├── services/                    I/O boundaries, behind interfaces
│   ├── student_repository.dart  StudentRepository + InMemoryStudentRepository
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
    ├── theme/                   AppColors, AppTheme
    ├── constants/               AppStrings (all user-facing copy)
    └── utils/                   StudentNumber value object + input formatter
```

### Why it is split this way

- **`QrGeneratorController`** is a plain `ChangeNotifier`. It answers every
  question the UI asks (`canGenerate`, `primaryActionLabel`, `isVerified`), so
  widgets only render what they are told. The views subscribe with the built-in
  `ListenableBuilder` — no state-management package needed.
- **Services are `abstract interface class`es.** `InMemoryStudentRepository`
  ships demo data; swapping in an HTTP-backed implementation changes one line in
  `app.dart` and nothing else. Tests inject their own doubles the same way.
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

The app ships with demo data and switches to a real API when you build with a
base URL:

```bash
flutter build apk --release   --dart-define=API_BASE_URL=https://your-domain.example/api   --dart-define=API_KEY=your-shared-secret
```

`HttpStudentRepository` then replaces `InMemoryStudentRepository` — nothing else
in the app changes. Server side, drop `backend/student_lookup.php` into your
existing project and fill in the DB credentials and column names at the top.

### Host requirement

The host must answer requests that do not come from a browser. Free hosts
(InfinityFree among them) protect sites with a JavaScript cookie challenge:
a browser runs the script and retries, but a mobile app receives the HTML
challenge page instead of JSON and cannot proceed. Check yours before building:

```bash
backend/check_host.sh https://your-domain.example/api/student_lookup.php KEY
```

If it reports BLOCKED, move the API to a host that permits app traffic. The
Flutter side does not change — only `API_BASE_URL` does.

## Demo records

`019-464`, `025-1023`, `021-318`, `023-770`. The dash is inserted automatically;
type digits only.

## Running

```bash
flutter pub get
flutter run
flutter test      # 24 unit + widget tests
flutter analyze
```

## Layout

Single responsive screen. Panels sit side by side at ≥ 760 px wide and stack
below that; the header chips wrap under the title at ≥ 560 px. Content is
capped at 1040 px and centred.
