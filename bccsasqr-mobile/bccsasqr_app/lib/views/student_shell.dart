import 'package:flutter/material.dart';

import '../models/whats_new.dart';
import 'menu_shell.dart';

/// The parts of the student's side. Every one of them opens from the Menu
/// — the one button at the foot of the screen, as on the instructor's — and
/// Home's shortcuts open most of them too.
enum StudentTab {
  home,
  qr,
  tracker,
  checkIn,
  profile,
  settings;

  /// Where a What's New item about [area] opens.
  static StudentTab of(WhatsNewArea area) => switch (area) {
    WhatsNewArea.qr => qr,
    WhatsNewArea.tracker => tracker,
    WhatsNewArea.profile => profile,
    WhatsNewArea.checkIn => checkIn,
    // The instructor's, and left out of the student's What's New.
    WhatsNewArea.scanner || WhatsNewArea.links => home,
  };
}

/// A student's phone: a [MenuShell] opening on Home, which holds the QR code
/// itself. The Menu opens the rest: My QR Code, Attendance, Check in, My
/// Profile and Settings. Picked on 2026-10-01 to match the instructor's
/// side, so the app is one product to whoever holds it.
class StudentShell extends StatelessWidget {
  const StudentShell({
    super.key,
    required this.tab,
    required this.homeBuilder,
    required this.generatorBuilder,
    required this.trackerBuilder,
    required this.checkInBuilder,
    required this.profileBuilder,
    required this.settingsBuilder,
    required this.menuBuilder,
  });

  final ValueNotifier<StudentTab> tab;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder generatorBuilder;
  final WidgetBuilder trackerBuilder;
  final WidgetBuilder checkInBuilder;
  final WidgetBuilder profileBuilder;
  final WidgetBuilder settingsBuilder;
  final MenuBuilder<StudentTab> menuBuilder;

  WidgetBuilder _builder(StudentTab tab) => switch (tab) {
    StudentTab.home => homeBuilder,
    StudentTab.qr => generatorBuilder,
    StudentTab.tracker => trackerBuilder,
    StudentTab.checkIn => checkInBuilder,
    StudentTab.profile => profileBuilder,
    StudentTab.settings => settingsBuilder,
  };

  @override
  Widget build(BuildContext context) => MenuShell<StudentTab>(
    tab: tab,
    home: StudentTab.home,
    tabs: StudentTab.values,
    builder: _builder,
    menuBuilder: menuBuilder,
  );
}
