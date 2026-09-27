import 'package:bccsasqr_app/controllers/scanner_controller.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/views/scanner/camera/scan_highlight.dart';
import 'package:bccsasqr_app/views/scanner/widgets/camera_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A camera that "reads" a code on the frame after it is built, the way the
/// real one reports from its image stream.
class _ReadingCamera extends StatefulWidget {
  const _ReadingCamera({required this.onControl});

  final ValueChanged<ScanHighlightControl?> onControl;

  @override
  State<_ReadingCamera> createState() => _ReadingCameraState();
}

class _ReadingCameraState extends State<_ReadingCamera> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onControl(ScanHighlightScope.maybeOf(context));
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

Finder _painted() => find.descendant(
  of: find.byType(ScanHighlight),
  matching: find.byType(CustomPaint),
);

void main() {
  group('displayRotation', () {
    test('a phone held upright turns the usual sensor a quarter', () {
      expect(ScanQuad.displayRotation(90, DeviceOrientation.portraitUp), 90);
    });

    test('held sideways, the picture is already the right way', () {
      expect(ScanQuad.displayRotation(90, DeviceOrientation.landscapeLeft), 0);
      expect(
        ScanQuad.displayRotation(90, DeviceOrientation.landscapeRight),
        180,
      );
    });

    test('an upside-down sensor turns the other way', () {
      expect(ScanQuad.displayRotation(270, DeviceOrientation.portraitUp), 270);
    });
  });

  group('fromCrop', () {
    // A 1280 × 720 frame: the 0.8 crop is 576 px square.
    ScanQuad? quad(List<Offset> points, int rotation) => ScanQuad.fromCrop(
      imageWidth: 1280,
      imageHeight: 720,
      cropFraction: 0.8,
      points: points,
      rotation: rotation,
    );

    test('turned a quarter, the sensor\'s top-left is the screen\'s '
        'top-right', () {
      final q = quad(const [
        Offset(0, 0),
        Offset(576, 0),
        Offset(576, 576),
        Offset(0, 576),
      ], 90)!;

      expect(q.corners, const [
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
        Offset(0, 0),
      ]);
    });

    test('a code in the middle stays in the middle', () {
      final q = quad(const [
        Offset(188, 188),
        Offset(388, 188),
        Offset(388, 388),
        Offset(188, 388),
      ], 90)!;

      expect(q.center.dx, closeTo(0.5, 1e-9));
      expect(q.center.dy, closeTo(0.5, 1e-9));
    });

    test('without a turn the corners are just scaled', () {
      final q = quad(const [
        Offset(144, 0),
        Offset(288, 0),
        Offset(288, 144),
        Offset(144, 144),
      ], 0)!;

      expect(q.corners.first, const Offset(0.25, 0));
      expect(q.corners[2], const Offset(0.5, 0.25));
    });

    test('corners far outside the frame give no quad', () {
      expect(
        quad(const [
          Offset(0, 0),
          Offset(2000, 0),
          Offset(2000, 2000),
          Offset(0, 2000),
        ], 90),
        isNull,
      );
    });
  });

  test('a read with no position lights the whole frame', () {
    final control = ScanHighlightControl()..show(null);
    expect(control.quad, ScanQuad.frame);
    expect(control.reads, 1);
  });

  group('in the camera panel', () {
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(400, 900);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Widget panel(
      ValueChanged<ScanHighlightControl?> onControl, {
      bool still = false,
    }) => MaterialApp(
      theme: AppTheme.build(AppPalette.dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: child!,
      ),
      home: Scaffold(
        body: CameraPanel(
          active: true,
          recording: false,
          status: const ScanStatus('Ready'),
          cameraBuilder: (context) => _ReadingCamera(onControl: onControl),
        ),
      ),
    );

    testWidgets('the camera finds the highlight, and a read shows it', (
      tester,
    ) async {
      ScanHighlightControl? control;
      await tester.pumpWidget(panel((c) => control = c));
      await tester.pump();

      expect(control, isNotNull);
      expect(_painted(), findsNothing);

      control!.show(
        const ScanQuad([
          Offset(0.3, 0.3),
          Offset(0.7, 0.3),
          Offset(0.7, 0.7),
          Offset(0.3, 0.7),
        ]),
      );
      // One frame to start the ticker, then time for it to run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painted(), findsOneWidget);

      // Still up between one read and the next of a code held in view.
      await tester.pump(const Duration(milliseconds: 500));
      control!.show(
        const ScanQuad([
          Offset(0.35, 0.3),
          Offset(0.75, 0.3),
          Offset(0.75, 0.7),
          Offset(0.35, 0.7),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(_painted(), findsOneWidget);

      // Gone once the code has been taken away.
      await tester.pump(ScanHighlight.linger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painted(), findsNothing);
    });

    testWidgets('with reduce motion on, it shows and goes without animating', (
      tester,
    ) async {
      ScanHighlightControl? control;
      await tester.pumpWidget(panel((c) => control = c, still: true));
      await tester.pump();

      control!.show(null);
      await tester.pump();
      expect(_painted(), findsOneWidget);

      await tester.pump(ScanHighlight.linger);
      await tester.pump();
      expect(_painted(), findsNothing);
    });
  });
}
