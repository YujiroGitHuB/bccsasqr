import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns the on-screen QR card into a PNG the student can keep.
abstract interface class QrExportService {
  /// Rasterises the widget behind [boundaryKey] and hands it to the platform
  /// share sheet. Returns the saved file path.
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileStem,
    String? shareText,
  });
}

class QrExportException implements Exception {
  const QrExportException(this.message);
  final String message;

  @override
  String toString() => 'QrExportException: $message';
}

class ImageQrExportService implements QrExportService {
  const ImageQrExportService({this.pixelRatio = 3.0});

  /// Render scale — 3x keeps the code crisp when printed or zoomed.
  final double pixelRatio;

  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileStem,
    String? shareText,
  }) async {
    final bytes = await _rasterise(boundaryKey);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileStem.png');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
      ),
    );
    return file.path;
  }

  Future<Uint8List> _rasterise(GlobalKey key) async {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw const QrExportException('QR code is not ready to be captured.');
    }

    final image = await object.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const QrExportException('Could not encode the QR image.');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
