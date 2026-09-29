import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a network to reach the server over.
abstract interface class ConnectivityService {
  /// True while there is Wi-Fi, mobile data or another network; false with
  /// none. The first event is how things stand now; after that, changes.
  Stream<bool> get online;
}

/// The phone's own, through connectivity_plus.
///
/// A network is not the internet — a Wi-Fi with a sign-in page has one and
/// not the other — so this only drives the "You're offline" notice. Every
/// request still says for itself when it could not get through (see
/// core/utils/network_error.dart).
class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get online => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none))
      // A platform that cannot say is treated as saying nothing.
      .handleError((Object _) {});
}
