import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Where a new photo comes from.
enum PhotoOrigin { camera, gallery }

/// Hands over a picture the student took or chose, or null when they backed
/// out. Behind an interface so a test needs no camera.
abstract interface class PhotoPicker {
  Future<Uint8List?> pick(PhotoOrigin origin);
}

/// The phone's own camera app and photo picker.
///
/// The picture is scaled down on the phone before it is read — a 12 MP photo
/// is 48 MB once decoded, and the crop only ever keeps a 400 px square of it.
/// The camera permission the scanner declares is asked for here too when
/// needed; image_picker asks for it itself.
class DevicePhotoPicker implements PhotoPicker {
  const DevicePhotoPicker();

  static const double _maxSide = 1600;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    final file = await ImagePicker().pickImage(
      source: origin == PhotoOrigin.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // A hint: the camera app may still open on the back camera.
      preferredCameraDevice: CameraDevice.front,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: 92,
      // Nothing from the file's metadata is used, so none is asked for — and
      // on iOS that keeps the photo library's permission prompt away.
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}
