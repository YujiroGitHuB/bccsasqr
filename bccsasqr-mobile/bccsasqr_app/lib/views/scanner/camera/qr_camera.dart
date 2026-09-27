/// The camera that reads student QR codes.
///
/// On a phone it is ZXing through flutter_zxing (qr_camera_device.dart). The
/// web build — used for checking the screens in a browser — gets a panel to
/// type a number into instead (qr_camera_fallback.dart), since the native
/// decoder does not run there.
library;

export 'qr_camera_fallback.dart' if (dart.library.io) 'qr_camera_device.dart';
