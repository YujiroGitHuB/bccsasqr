/// Build-time configuration.
///
/// Values come from `--dart-define` so the API host and key never sit in the
/// source tree:
///
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=http://10.0.2.2/bccsasqr/api/v1 \
///   --dart-define=API_KEY=your-shared-secret
/// ```
///
/// With no `API_BASE_URL` the app falls back to the bundled demo records, so it
/// still runs offline.
///
/// `API_BASE_URL` points at the **versioned API root**, not at a single script:
///
/// | Where the app runs            | value                                      |
/// |-------------------------------|--------------------------------------------|
/// | Android emulator → XAMPP      | `http://10.0.2.2/bccsasqr/api/v1`           |
/// | iOS simulator → XAMPP         | `http://localhost/bccsasqr/api/v1`          |
/// | Real phone on the same wifi   | `http://192.168.x.x/bccsasqr/api/v1`        |
/// | Deployed                      | `https://your-host/bccsasqr/api/v1`         |
///
/// If the host has no `mod_rewrite`, append `/index.php` to the value — the
/// API answers on that form too.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String apiKey = String.fromEnvironment('API_KEY');

  /// True when a real backend was supplied at build time.
  static bool get hasRemoteApi => apiBaseUrl.isNotEmpty;

  static const Duration requestTimeout = Duration(seconds: 15);
}
