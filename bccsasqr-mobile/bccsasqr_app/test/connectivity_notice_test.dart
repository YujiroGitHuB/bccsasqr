import 'dart:async';

import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/services/connectivity.dart';
import 'package:bccsasqr_app/views/widgets/connectivity_notice.dart';
import 'package:bccsasqr_app/views/widgets/island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A network the test switches on and off.
class _Network implements ConnectivityService {
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  void set(bool online) => _changes.add(online);

  @override
  Stream<bool> get online => _changes.stream;
}

void main() {
  late _Network network;

  setUp(() => network = _Network());

  Widget app() => MaterialApp(
    theme: AppTheme.build(AppPalette.dark),
    builder: (context, child) => IslandHost(
      child: ConnectivityNotice(connectivity: network, child: child!),
    ),
    home: const Scaffold(body: Text('page')),
  );

  /// The island's drop, far enough in to read.
  Future<void> shown(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('opening online says nothing', (tester) async {
    await tester.pumpWidget(app());
    network.set(true);
    await shown(tester);

    expect(find.text(OfflineStrings.back), findsNothing);
    expect(find.text(OfflineStrings.title), findsNothing);
  });

  testWidgets('losing the connection says so, and so does getting it back', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    network.set(true);
    await shown(tester);

    network.set(false);
    await shown(tester);
    expect(find.text(OfflineStrings.title), findsOneWidget);
    expect(find.text(OfflineStrings.body), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text(OfflineStrings.title), findsNothing);

    // The same news twice is said once.
    network.set(false);
    await shown(tester);
    expect(find.text(OfflineStrings.title), findsNothing);

    network.set(true);
    await shown(tester);
    expect(find.text(OfflineStrings.back), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('opening offline says so at once', (tester) async {
    await tester.pumpWidget(app());
    network.set(false);
    await shown(tester);

    expect(find.text(OfflineStrings.title), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('with nothing to watch, nothing is said', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => IslandHost(
          child: ConnectivityNotice(connectivity: null, child: child!),
        ),
        home: const Scaffold(body: Text('page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('page'), findsOneWidget);
    expect(find.text(OfflineStrings.title), findsNothing);
  });
}
