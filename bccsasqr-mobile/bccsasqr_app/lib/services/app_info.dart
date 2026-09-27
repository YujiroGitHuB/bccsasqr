import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_config.dart';

/// What the About section says about this install.
class AppInfo {
  const AppInfo({required this.version, required this.buildNumber});

  /// `1.1.0` — the `version:` in pubspec.yaml, before the `+`.
  final String version;

  /// `2` — after the `+`. Android's versionCode: a phone only accepts an
  /// update whose build number is higher than the one installed.
  final String buildNumber;

  /// "1.1.0 (build 2)", or just the version when there is no build number.
  String get label =>
      buildNumber.isEmpty ? version : '$version (build $buildNumber)';

  /// Read from the installed package rather than written into the source, so
  /// it can never disagree with what Android shows in App info.
  static Future<AppInfo> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppInfo(version: info.version, buildNumber: info.buildNumber);
    } catch (_) {
      return const AppInfo(version: '—', buildNumber: '');
    }
  }

  /// The server this build talks to — `lexondev.com` — or null in demo mode.
  static String? get serverHost {
    if (!AppConfig.hasRemoteApi) return null;
    final host = Uri.tryParse(AppConfig.apiBaseUrl)?.host ?? '';
    return host.isEmpty ? AppConfig.apiBaseUrl : host;
  }

  /// The page students download the app from, next to the API it talks to:
  /// `…/bccsasqr/api/v1` → `…/bccsasqr/download/`. The app is installed from
  /// there, not a store, so this is where an update comes from.
  static String? get downloadPageUrl {
    if (!AppConfig.hasRemoteApi) return null;
    final base = AppConfig.apiBaseUrl
        .replaceAll(RegExp(r'/+$'), '')
        .replaceAll(RegExp(r'/index\.php$'), '');
    final root = base.replaceAll(RegExp(r'/api/v1$'), '');
    return root == base ? null : '$root/download/';
  }
}
