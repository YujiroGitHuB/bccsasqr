import 'dart:typed_data';

import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/phone_lock_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/models/student_profile.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/photo_repository.dart';
import 'package:bccsasqr_app/services/profile_store.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/widgets/phone_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up students only: year 000 never occurs in the school's numbers.
final _number = StudentNumber.tryParse('000-1023')!;

final _record = StudentRecord(
  studentNumber: _number,
  fullName: 'DELA CRUZ, JUAN P.',
  course: 'BSIT',
  section: '2A',
);

final _kept = StudentProfile(record: _record, lastName: 'Dela Cruz');

/// Takes any student number and last name as the made-up student's.
class _Photos implements StudentPhotoRepository {
  @override
  Future<PhotoOwner> verifyOwner(StudentNumber number, String lastName) async =>
      (record: _record, photoUrl: null, required: false);

  @override
  Future<PhotoOwner> fetchOwner(StudentNumber number) async =>
      (record: _record, photoUrl: null, required: false);

  @override
  Future<PhotoOwner> uploadPhoto(
    StudentNumber number,
    String lastName,
    Uint8List jpeg,
  ) async => (record: _record, photoUrl: null, required: false);

  @override
  Future<Uint8List> downloadPhoto(String url) async =>
      throw UnimplementedError();
}

class _Tracker implements TrackerRepository {
  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async =>
      AttendanceHistory(
        studentNumber: _number.value,
        fullName: _record.fullName,
        course: 'BSIT',
        section: '2A',
        total: 0,
        subjects: const [],
      );
}

/// A phone whose lock answers from a script: the next results in order,
/// "unlocked" once the script runs out.
class _FakeDeviceLock implements DeviceLock {
  bool available = true;
  final List<DeviceUnlock> script = [];
  final List<String> asked = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceUnlock> unlock(String reason) async {
    asked.add(reason);
    return script.isEmpty ? DeviceUnlock.unlocked : script.removeAt(0);
  }
}

void main() {
  late _FakeDeviceLock device;
  late MemoryLockSwitchStore store;
  late MemoryProfileStore profiles;
  late DateTime now;

  setUp(() {
    device = _FakeDeviceLock();
    store = MemoryLockSwitchStore();
    profiles = MemoryProfileStore(_kept);
    now = DateTime(2026, 10, 1, 8);
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 1000);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget app() => BccSasqrApp(
    roleStore: MemoryRoleStore(AppRole.student),
    profileStore: profiles,
    photoRepository: _Photos(),
    trackerRepository: _Tracker(),
    speech: const SilentSpeechService(),
    settingsStore: MemorySettingsStore(),
    deviceLock: device,
    studentLockStore: store,
    lockClock: () => now,
    cameraBuilder: (context, onCode) => const SizedBox(),
    showSplash: false,
  );

  final home = find.byKey(const ValueKey('studentHome'));
  final lockScreen = find.byType(PhoneLockScreen);

  /// The app closed and opened again — the profile, the switch and the
  /// phone all kept — stopped short of the prompt, which goes up by itself
  /// a moment after the lock screen does.
  Future<void> relaunch(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openFromMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const ValueKey('nav.menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('menu.$item')));
    await tester.pumpAndSettle();
  }

  testWidgets('off until the student turns it on: the app opens on Home', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
    expect(device.asked, isEmpty);
  });

  testWidgets('turned on in Settings → Privacy, the next launch opens on '
      'the lock, and the fingerprint opens Home', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openFromMenu(tester, 'settings');

    expect(find.text(StudentLockStrings.section), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings.lock')));
    await tester.pumpAndSettle();
    // The phone's own lock first, so the finger that opens it is the owner's.
    expect(device.asked, [StudentLockStrings.enableReason]);
    expect(store.enabled, isTrue);

    await relaunch(tester);
    expect(lockScreen, findsOneWidget);
    expect(find.text(StudentLockStrings.title), findsOneWidget);
    // Whose phone it is, by the name they are greeted by.
    expect(find.text('Juan'), findsOneWidget);
    // Nothing of the side is there before it opens.
    expect(home, findsNothing);
    expect(find.byKey(const ValueKey('nav.menu')), findsNothing);

    await tester.pump(PhoneLockScreen.promptDelay);
    await tester.pumpAndSettle();
    expect(device.asked.last, StudentLockStrings.reason);
    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
  });

  testWidgets('a prompt closed without a finger keeps it shut, and says so', (
    tester,
  ) async {
    store.enabled = true;
    device.script.add(DeviceUnlock.cancelled);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump(PhoneLockScreen.promptDelay);
    await tester.pumpAndSettle();

    expect(lockScreen, findsOneWidget);
    expect(find.text(StudentLockStrings.notUnlocked), findsOneWidget);
    expect(home, findsNothing);

    await tester.tap(find.byKey(const ValueKey('lock.unlock')));
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
  });

  testWidgets('a minute away locks it again, closing what was open over it', (
    tester,
  ) async {
    store.enabled = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump(PhoneLockScreen.promptDelay);
    await tester.pumpAndSettle();
    expect(home, findsOneWidget);

    // A page over the side, which the lock must not stay behind.
    await openFromMenu(tester, 'whatsNew');
    expect(find.text(WhatsNewStrings.title), findsWidgets);

    // Away, a minute passes, back — one lifecycle step at a time.
    void step(AppLifecycleState state) =>
        tester.binding.handleAppLifecycleStateChanged(state);
    step(AppLifecycleState.inactive);
    step(AppLifecycleState.hidden);
    now = now.add(PhoneLockController.relockAfter);
    device.script.add(DeviceUnlock.cancelled);
    step(AppLifecycleState.inactive);
    step(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pump(PhoneLockScreen.promptDelay);
    await tester.pumpAndSettle();

    expect(lockScreen, findsOneWidget);
    expect(find.text(WhatsNewStrings.title), findsNothing);
    // Kept under the lock, but out of reach.
    expect(find.byKey(const ValueKey('nav.menu')).hitTestable(), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lock.unlock')));
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    expect(home, findsOneWidget);
  });

  testWidgets('"Not you?" on the lock asks, then the phone forgets the '
      'student, and the lock with them', (tester) async {
    store.enabled = true;
    device.script.add(DeviceUnlock.cancelled);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.pump(PhoneLockScreen.promptDelay);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lock.notYou')));
    await tester.pumpAndSettle();
    expect(find.text(StudentStrings.forgetTitle), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('menu.notYou.confirm')));
    await tester.pumpAndSettle();

    expect(lockScreen, findsNothing);
    expect(store.enabled, isFalse);
    expect(profiles.profile, isNull);
    // Open, on the set-up: nothing of theirs is shown.
    expect(find.text(StudentStrings.setUpBody), findsOneWidget);
  });

  testWidgets('a phone whose screen lock was taken away turns the lock off, '
      'and says so', (tester) async {
    store.enabled = true;
    device.available = false;
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(StudentLockStrings.lostTitle), findsOneWidget);
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    expect(store.enabled, isFalse);
    expect(home, findsOneWidget);
  });

  testWidgets('offered once, right after the phone is set up', (tester) async {
    profiles = MemoryProfileStore();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(StudentLockStrings.offerTitle), findsNothing);

    await openFromMenu(tester, 'profile');
    await tester.enterText(
      find.byKey(const ValueKey('profile.number')),
      '0001023',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile.lastName')),
      'dela cruz',
    );
    await tester.tap(find.byKey(const ValueKey('profile.verify')));
    await tester.pumpAndSettle();

    expect(find.text(StudentLockStrings.offerTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lock.offer.on')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(device.asked, [StudentLockStrings.enableReason]);
    expect(store.enabled, isTrue);
    expect(find.text(StudentLockStrings.on), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a phone with no screen lock has no switch, and no offer', (
    tester,
  ) async {
    device.available = false;
    profiles = MemoryProfileStore();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await openFromMenu(tester, 'settings');
    expect(find.text(StudentLockStrings.section), findsNothing);
    expect(find.byKey(const ValueKey('settings.lock')), findsNothing);

    await openFromMenu(tester, 'profile');
    await tester.enterText(
      find.byKey(const ValueKey('profile.number')),
      '0001023',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile.lastName')),
      'dela cruz',
    );
    await tester.tap(find.byKey(const ValueKey('profile.verify')));
    await tester.pumpAndSettle();
    expect(find.text('DELA CRUZ, JUAN P.'), findsWidgets);
    expect(find.text(StudentLockStrings.offerTitle), findsNothing);
    expect(device.asked, isEmpty);
  });
}
