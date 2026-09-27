import 'package:bccsasqr_app/controllers/scanner_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/views/scanner/camera/torch_control.dart';
import 'package:bccsasqr_app/views/scanner/widgets/camera_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A camera that attaches a torch once it is "running", like the real one
/// does after the camera starts — never during the build.
class _TorchCamera extends StatefulWidget {
  const _TorchCamera({required this.switches, this.fails = false});

  final List<bool> switches;
  final bool fails;

  @override
  State<_TorchCamera> createState() => _TorchCameraState();
}

class _TorchCameraState extends State<_TorchCamera> {
  TorchControl? _torch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _torch = TorchScope.maybeOf(context)
        ?..attach((on) async {
          if (widget.fails) throw StateError('no flash');
          widget.switches.add(on);
        });
    });
  }

  @override
  void dispose() {
    _torch?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

void main() {
  late List<bool> switches;

  setUp(() {
    switches = [];
    // A phone, so the status line is on screen and the tap lands.
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

  Widget panel({required bool active, bool fails = false}) => MaterialApp(
    theme: AppTheme.build(AppPalette.dark),
    // The scan line sweeps forever; held still, pumpAndSettle can settle.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: CameraPanel(
          active: active,
          recording: false,
          status: const ScanStatus('Ready'),
          cameraBuilder: (context) =>
              _TorchCamera(switches: switches, fails: fails),
        ),
      ),
    ),
  );

  final torch = find.byKey(const ValueKey('scanner.torch'));

  testWidgets('no flashlight button before the camera is running', (
    tester,
  ) async {
    await tester.pumpWidget(panel(active: false));
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.cameraIdle), findsOneWidget);
    expect(torch, findsNothing);
  });

  testWidgets('the flashlight button sits under the picture and switches '
      'the torch', (tester) async {
    await tester.pumpWidget(panel(active: true));
    await tester.pumpAndSettle();

    expect(torch, findsOneWidget);
    expect(find.text(ScannerStrings.flashlight), findsOneWidget);
    expect(find.byIcon(Icons.flashlight_off_rounded), findsOneWidget);

    // Below the camera square, not drawn over it.
    final camera = tester.getRect(find.byType(_TorchCamera));
    expect(tester.getRect(torch).top, greaterThan(camera.bottom));

    await tester.tap(torch);
    await tester.pumpAndSettle();
    expect(switches, [true]);
    expect(find.byIcon(Icons.flashlight_on_rounded), findsOneWidget);

    await tester.tap(torch);
    await tester.pumpAndSettle();
    expect(switches, [true, false]);
    expect(find.byIcon(Icons.flashlight_off_rounded), findsOneWidget);
  });

  testWidgets('the button goes with the camera', (tester) async {
    await tester.pumpWidget(panel(active: true));
    await tester.pumpAndSettle();
    expect(torch, findsOneWidget);

    await tester.pumpWidget(panel(active: false));
    await tester.pumpAndSettle();
    expect(torch, findsNothing);
  });

  testWidgets('a phone with no flash loses the button on the first try', (
    tester,
  ) async {
    await tester.pumpWidget(panel(active: true, fails: true));
    await tester.pumpAndSettle();

    await tester.tap(torch);
    await tester.pumpAndSettle();
    expect(torch, findsNothing);
  });
}
