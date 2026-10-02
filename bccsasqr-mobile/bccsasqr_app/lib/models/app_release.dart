import 'package:flutter/foundation.dart';

/// What `GET /api/v1/app` says: the app on the download page — read by the
/// server from the uploaded APK itself (includes/app_release.php) — and the
/// oldest build still allowed to run.
@immutable
class AppRelease {
  const AppRelease({
    this.version,
    this.build,
    this.size,
    this.minBuild = 0,
    this.downloadUrl,
  });

  /// "1.17.0" and 21 — pubspec.yaml's version on either side of the `+`.
  /// Null with no APK on the server: nothing to offer.
  final String? version;
  final int? build;

  /// The APK's size in bytes — said on the card, for a phone on mobile data.
  final int? size;

  /// A build under this no longer works with the server.
  final int minBuild;

  /// The download page, as the server knows its own address.
  final String? downloadUrl;

  /// The size in whole megabytes, as the download page rounds it; null when
  /// not known.
  int? get megabytes => switch (size) {
    final bytes? when bytes > 0 => (bytes / 1048576).round(),
    _ => null,
  };

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final latest = json['latest'];
    final url = json['download_url'];
    return AppRelease(
      version: latest is Map<String, dynamic> && latest['version'] is String
          ? latest['version'] as String
          : null,
      build: latest is Map<String, dynamic> && latest['build'] is int
          ? latest['build'] as int
          : null,
      size: latest is Map<String, dynamic> && latest['size'] is int
          ? latest['size'] as int
          : null,
      minBuild: json['min_build'] is int ? json['min_build'] as int : 0,
      downloadUrl: url is String && url.isNotEmpty ? url : null,
    );
  }
}
