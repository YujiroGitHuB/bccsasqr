import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/views/widgets/island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A page with two buttons that put messages on the island.
  Widget app() => MaterialApp(
    theme: AppTheme.build(AppPalette.light),
    builder: (context, child) => IslandHost(child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Island.show(
                  context,
                  const IslandMessage(
                    title: 'QR code saved',
                    tone: IslandTone.success,
                  ),
                ),
                child: const Text('first'),
              ),
              TextButton(
                onPressed: () => Island.show(
                  context,
                  const IslandMessage(
                    title: 'Not enrolled',
                    body: 'Student 000-0001 is not enrolled.',
                    tone: IslandTone.error,
                    hold: Duration(seconds: 4),
                  ),
                ),
                child: const Text('second'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('drops in, holds, and goes back into the top by itself', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('first'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('QR code saved'), findsOneWidget);
    // Near the top of the screen, not at the bottom like a SnackBar.
    expect(tester.getCenter(find.text('QR code saved')).dy, lessThan(120));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('QR code saved'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('QR code saved'), findsNothing);
  });

  testWidgets('the newest wins, and a tap puts it away early', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('first'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('QR code saved'), findsNothing);
    expect(find.text('Not enrolled'), findsOneWidget);
    expect(find.text('Student 000-0001 is not enrolled.'), findsOneWidget);

    await tester.tap(find.text('Not enrolled'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Not enrolled'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('with reduce motion on, it still stays long enough to read', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app());
    await tester.tap(find.text('first'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('QR code saved'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('QR code saved'), findsNothing);
  });
}
