import '../models/app_release.dart';

/// Which app is on the download page — `GET /api/v1/app`. The app is
/// installed from there, not from a store, so nothing else would ever tell
/// a phone that it is out of date.
///
/// Raises a StudentLookupException when the server cannot be reached or
/// says no; the update check then simply offers nothing until it asks again.
abstract interface class AppReleaseRepository {
  Future<AppRelease> fetchRelease();
}
