import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the scanner's sign-in token is kept between launches.
///
/// The token stands in for the instructor's password — anyone holding it can
/// record attendance under their name — so on the phone it lives in the
/// platform keystore, not in plain preferences.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// The Android Keystore / iOS Keychain, through flutter_secure_storage.
///
/// A store that cannot be read (a keystore reset by a restore from backup, a
/// device without one) answers "signed out" rather than crashing the scanner:
/// signing in again is the fix either way.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'scanner_auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Signed in for this launch only — the next one asks again.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing readable to clear.
    }
  }
}

/// Keeps the token for the life of the object. For tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
