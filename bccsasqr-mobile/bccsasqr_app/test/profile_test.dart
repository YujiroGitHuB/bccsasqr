import 'dart:async';
import 'dart:typed_data';

import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/my_attendance_controller.dart';
import 'package:bccsasqr_app/controllers/my_qr_controller.dart';
import 'package:bccsasqr_app/controllers/profile_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/student_profile.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/services/photo_picker.dart';
import 'package:bccsasqr_app/services/photo_repository.dart';
import 'package:bccsasqr_app/services/profile_store.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/saved_qr_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/home_page.dart';
import 'package:bccsasqr_app/views/profile/photo_crop_page.dart';
import 'package:bccsasqr_app/views/profile/profile_page.dart';
import 'package:bccsasqr_app/views/profile/profile_splash.dart';
import 'package:bccsasqr_app/views/student_shell.dart';
import 'package:bccsasqr_app/views/widgets/island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Made-up students only: year 000 never occurs in the school's numbers.
final _number = StudentNumber.tryParse('000-1023')!;

final _record = StudentRecord(
  studentNumber: _number,
  fullName: 'SANTOS, MARIA ISABEL B.',
  course: 'BSCS',
  section: '2B',
);

final Uint8List _oldPhoto = Uint8List.fromList(List.filled(8, 1));
final Uint8List _newPhoto = Uint8List.fromList(List.filled(8, 2));

/// The server, as far as My Profile sees it.
class _FakePhotos implements StudentPhotoRepository {
  String? url;
  bool required = false;
  StudentLookupException? failure;
  final List<Uint8List> uploads = [];
  final List<String> downloads = [];

  /// Held open until completed, to see the page mid-upload.
  Completer<void>? gate;

  PhotoOwner get _owner => (record: _record, photoUrl: url, required: required);

  @override
  Future<PhotoOwner> verifyOwner(StudentNumber number, String lastName) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    if (number != _number || lastName.toUpperCase() != 'SANTOS') {
      throw const StudentLookupException(
        'Incorrect student number or last name.',
        code: 'identity_mismatch',
      );
    }
    return _owner;
  }

  @override
  Future<PhotoOwner> fetchOwner(StudentNumber number) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return _owner;
  }

  @override
  Future<PhotoOwner> uploadPhoto(
    StudentNumber number,
    String lastName,
    Uint8List jpeg,
  ) async {
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    uploads.add(jpeg);
    url =
        'https://example.test/uploads/photos/student_1.jpg?v=${uploads.length}';
    return _owner;
  }

  @override
  Future<Uint8List> downloadPhoto(String url) async {
    downloads.add(url);
    return _oldPhoto;
  }
}

/// Hands back a fixed picture, or none.
class _FakePicker implements PhotoPicker {
  _FakePicker([this.photo]);

  final Uint8List? photo;
  final List<PhotoOrigin> asked = [];

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    asked.add(origin);
    return photo;
  }
}

StudentProfile _kept({Uint8List? photo, String? url}) => StudentProfile(
  record: _record,
  lastName: 'Santos',
  photo: photo,
  photoUrl: url,
);

void main() {
  group('StudentProfile', () {
    test('greets by the given name, without the middle initial', () {
      for (final (full, given) in [
        ('SANTOS, MARIA ISABEL B.', 'Maria Isabel'),
        ('DELA CRUZ, JUAN', 'Juan'),
        ('REYES, MA. ANGELICA', 'Ma. Angelica'),
        ('LIM, JOHN-PAUL R', 'John-Paul'),
        ('Maria Isabel Santos', 'Maria'),
        ('SANTOS,', ''),
      ]) {
        expect(StudentProfile.givenNameOf(full), given, reason: full);
      }
    });

    test('keeps the photo through a save and a load', () {
      final profile = _kept(photo: _oldPhoto, url: 'https://x.test/a.jpg');
      final back = StudentProfile.fromJson(profile.toJson());

      expect(back.record, profile.record);
      expect(back.lastName, 'Santos');
      expect(back.photo, _oldPhoto);
      expect(back.photoUrl, 'https://x.test/a.jpg');
      expect(back.hasPhoto, isTrue);
    });

    test(
      'demo mode takes the last name before the comma, or the last word',
      () {
        expect(
          InMemoryPhotoRepository.lastNameOf('DELA CRUZ, JUAN'),
          'DELA CRUZ',
        );
        expect(
          InMemoryPhotoRepository.lastNameOf('Maria Isabel Santos'),
          'SANTOS',
        );
      },
    );
  });

  group('ProfileController', () {
    late _FakePhotos photos;
    late MemoryProfileStore store;
    late ProfileController controller;

    setUp(() {
      photos = _FakePhotos();
      store = MemoryProfileStore();
      controller = ProfileController(store: store, repository: photos);
    });

    test('asks for each field before calling the server', () async {
      await controller.load();

      expect(await controller.verify('', 'Santos'), isFalse);
      expect(controller.error, AppStrings.errorEmpty);
      expect(await controller.verify('0001', 'Santos'), isFalse);
      expect(controller.error, AppStrings.errorFormat);
      expect(await controller.verify('000-1023', '  '), isFalse);
      expect(controller.error, ProfileStrings.errorLastName);
      expect(controller.profile, isNull);
    });

    test('a verified student is kept, their photo with them', () async {
      photos.url = 'https://example.test/uploads/photos/student_1.jpg?v=1';
      await controller.load();

      expect(await controller.verify('000-1023', ' santos '), isTrue);

      expect(controller.error, isNull);
      expect(controller.profile!.record, _record);
      expect(controller.profile!.lastName, 'santos');
      expect(controller.profile!.photo, _oldPhoto);
      expect(photos.downloads, [photos.url]);
      expect(store.profile!.photo, _oldPhoto, reason: 'kept for offline');
    });

    test('a wrong last name says so and keeps nothing', () async {
      await controller.load();

      expect(await controller.verify('000-1023', 'Reyes'), isFalse);
      expect(controller.error, 'Incorrect student number or last name.');
      expect(store.profile, isNull);
    });

    test('the limit is named for what it is: fifteen minutes', () async {
      photos.failure = const StudentLookupException(
        'Too many requests. Please wait a moment and try again.',
        code: 'rate_limited',
      );
      await controller.load();

      await controller.verify('000-1023', 'Santos');
      expect(controller.error, ProfileStrings.tooManyTries);
    });

    test('a new photo shows while it goes up, then is kept', () async {
      store.profile = _kept(photo: _oldPhoto);
      await controller.load();
      photos.gate = Completer<void>();

      final saving = controller.savePhoto(_newPhoto);
      expect(controller.isSaving, isTrue);
      expect(controller.pendingPhoto, _newPhoto);

      photos.gate!.complete();
      expect(await saving, isNull);
      expect(controller.isSaving, isFalse);
      expect(controller.pendingPhoto, isNull);
      expect(controller.profile!.photo, _newPhoto);
      expect(controller.profile!.photoUrl, contains('student_1.jpg'));
      expect(store.profile!.photo, _newPhoto);
      expect(photos.uploads, [_newPhoto]);
    });

    test('a photo the server refuses leaves the old one', () async {
      store.profile = _kept(photo: _oldPhoto);
      await controller.load();
      photos.failure = const StudentLookupException(
        'No internet connection.',
        code: 'network',
      );

      expect(await controller.savePhoto(_newPhoto), 'No internet connection.');
      expect(controller.profile!.photo, _oldPhoto);
      expect(controller.pendingPhoto, isNull);
    });

    test('a refresh picks up a photo uploaded in the browser', () async {
      store.profile = _kept();
      await controller.load();
      photos.url = 'https://example.test/uploads/photos/student_1.jpg?v=9';

      await controller.refresh();

      expect(controller.profile!.photoUrl, photos.url);
      expect(controller.profile!.photo, _oldPhoto);
      expect(store.profile!.photoUrl, photos.url);
    });

    test('offline, a refresh keeps what the phone has', () async {
      store.profile = _kept(photo: _oldPhoto, url: 'https://x.test/a.jpg');
      await controller.load();
      photos.failure = const StudentLookupException('offline', code: 'network');

      await controller.refresh();

      expect(controller.profile!.photo, _oldPhoto);
      expect(controller.profile!.photoUrl, 'https://x.test/a.jpg');
    });

    test('"Not you?" forgets the student on this phone', () async {
      store.profile = _kept(photo: _oldPhoto);
      await controller.load();

      await controller.forget();

      expect(controller.profile, isNull);
      expect(store.profile, isNull);
    });
  });

  group('PhotoCropPage.sourceRect', () {
    test('untouched, it is the centred square of the picture', () {
      // A 800 × 1200 portrait in a 400 px square: cover = 0.5, centred by
      // lifting it 100 px.
      final rect = PhotoCropPage.sourceRect(
        Matrix4.translationValues(0, -100, 0),
        400,
        0.5,
      );
      expect(rect, const Rect.fromLTWH(0, 200, 800, 800));
    });

    test(
      'zoomed twice and moved, it is the smaller square under the circle',
      () {
        final transform = Matrix4.translationValues(-200, -300, 0)
          ..scaleByDouble(2, 2, 1, 1);
        final rect = PhotoCropPage.sourceRect(transform, 400, 0.5);
        expect(rect, const Rect.fromLTWH(200, 300, 400, 400));
      },
    );
  });

  group('screens', () {
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(420, 1400);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Widget app(Widget home) => MaterialApp(
      theme: AppTheme.build(AppPalette.light),
      builder: (context, child) => IslandHost(child: child!),
      home: home,
    );

    testWidgets('verify, then take a photo, crop it, and it is saved', (
      tester,
    ) async {
      final photos = _FakePhotos();
      final controller = ProfileController(
        store: MemoryProfileStore(),
        repository: photos,
      );
      await controller.load();
      final picker = _FakePicker(_newPhoto);
      Uint8List? cropped;

      await tester.pumpWidget(
        app(
          ProfilePage(
            controller: controller,
            picker: picker,
            cropper: (context, photo, _) async => cropped = photo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.verifyTitle), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('profile.number')),
        '0001023',
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile.lastName')),
        'reyes',
      );
      await tester.tap(find.byKey(const ValueKey('profile.verify')));
      await tester.pumpAndSettle();
      expect(
        find.text('Incorrect student number or last name.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('profile.lastName')),
        'santos',
      );
      await tester.tap(find.byKey(const ValueKey('profile.verify')));
      await tester.pumpAndSettle();

      expect(find.text('SANTOS, MARIA ISABEL B.'), findsOneWidget);
      expect(find.text('000-1023'), findsOneWidget);
      expect(find.text(ProfileStrings.statusNone), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile.camera')));
      // The island opens, holds and closes; read it while it is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(picker.asked, [PhotoOrigin.camera]);
      expect(cropped, _newPhoto);
      expect(photos.uploads, [_newPhoto]);
      expect(find.text(ProfileStrings.savedTitle), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.statusOnFile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('backing out of the camera changes nothing', (tester) async {
      final photos = _FakePhotos();
      final controller = ProfileController(
        store: MemoryProfileStore(_kept()),
        repository: photos,
      );
      await controller.load();

      await tester.pumpWidget(
        app(ProfilePage(controller: controller, picker: _FakePicker())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile.gallery')));
      await tester.pumpAndSettle();

      expect(photos.uploads, isEmpty);
      expect(find.text(ProfileStrings.statusNone), findsOneWidget);
    });

    testWidgets('the camera badge offers both, in a sheet', (tester) async {
      final photos = _FakePhotos();
      final controller = ProfileController(
        store: MemoryProfileStore(_kept()),
        repository: photos,
      );
      await controller.load();
      final picker = _FakePicker(_newPhoto);

      await tester.pumpWidget(
        app(
          ProfilePage(
            controller: controller,
            picker: picker,
            cropper: (context, photo, _) async => photo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile.badge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile.sheet.gallery')));
      await tester.pumpAndSettle();

      expect(picker.asked, [PhotoOrigin.gallery]);
      expect(photos.uploads, [_newPhoto]);
    });

    testWidgets('"Not you?" asks first, then goes back to the form', (
      tester,
    ) async {
      final store = MemoryProfileStore(_kept(photo: _oldPhoto));
      final controller = ProfileController(
        store: store,
        repository: _FakePhotos(),
      );
      await controller.load();

      await tester.pumpWidget(app(ProfilePage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile.forget')));
      await tester.tap(find.byKey(const ValueKey('profile.forget')));
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.forgetTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile.forget.confirm')));
      await tester.pumpAndSettle();

      expect(store.profile, isNull);
      expect(find.text(ProfileStrings.verifyTitle), findsOneWidget);
    });

    testWidgets('the crop hands back a square JPEG', (tester) async {
      // A real picture through the real decoder and encoder: 300 × 200.
      final source = img.encodePng(img.Image(width: 300, height: 200));
      Uint8List? result;

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async =>
                    result = await Navigator.of(context).push<Uint8List>(
                      MaterialPageRoute(
                        builder: (_) => PhotoCropPage(photo: source),
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // The route's first frame starts the decode; the decoder is real, so
      // it needs real time.
      await tester.pump();
      for (var i = 0; i < 20 && find.byType(RawImage).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.cropHint), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('crop.use')));
      for (var i = 0; i < 20 && result == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.sublist(0, 2), [0xFF, 0xD8], reason: 'a JPEG');
      final decoded = img.decodeJpg(result!)!;
      expect((decoded.width, decoded.height), (400, 400));
    });

    /// Home over [controller], with the student's code and attendance from
    /// the bundled sample records. [opened] collects the tabs it asks for.
    Widget home(
      ProfileController controller, {
      int hour = 9,
      List<StudentTab>? opened,
    }) {
      final qr = MyQrController(
        profile: controller,
        saved: WatchedSavedQrStore(MemorySavedQrStore()),
        repository: InMemoryStudentRepository(latency: Duration.zero),
      );
      final attendance = MyAttendanceController(
        profile: controller,
        repository: InMemoryTrackerRepository(latency: Duration.zero),
      );
      addTearDown(() {
        qr.dispose();
        attendance.dispose();
      });
      return app(
        HomePage(
          profile: controller,
          qr: qr,
          attendance: attendance,
          onOpen: (tab) => opened?.add(tab),
          onShowQr: () {},
          now: () => DateTime(2026, 9, 30, hour),
        ),
      );
    }

    testWidgets('home asks for a photo until there is one', (tester) async {
      final controller = ProfileController(
        store: MemoryProfileStore(
          StudentProfile(record: _record, lastName: 'Santos'),
        ),
        repository: _FakePhotos(),
      );
      await controller.load();
      final opened = <StudentTab>[];

      await tester.pumpWidget(home(controller, opened: opened));
      await tester.pumpAndSettle();

      expect(find.text('${AppStrings.homeMorning},'), findsOneWidget);
      expect(find.text(ProfileStrings.nudgeTitle), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home.profile')));
      await tester.tap(find.byKey(const ValueKey('home.photoNudge')));
      expect(opened, [StudentTab.profile, StudentTab.profile]);
    });

    testWidgets('before the phone is set up, home asks for that, not a '
        'photo', (tester) async {
      final controller = ProfileController(
        store: MemoryProfileStore(),
        repository: _FakePhotos(),
      );
      await controller.load();

      await tester.pumpWidget(home(controller));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.homeMorning), findsOneWidget);
      expect(find.text(StudentStrings.setUpBody), findsOneWidget);
      expect(find.text(ProfileStrings.nudgeTitle), findsNothing);
    });

    testWidgets('home greets the student by name, with their face', (
      tester,
    ) async {
      final controller = ProfileController(
        store: MemoryProfileStore(_kept(photo: _oldPhoto)),
        repository: _FakePhotos(),
      );
      await controller.load();

      await tester.pumpWidget(home(controller, hour: 20));
      await tester.pumpAndSettle();

      expect(find.text('Good evening,'), findsOneWidget);
      expect(find.text('Maria Isabel'), findsOneWidget);
      expect(find.text(ProfileStrings.nudgeTitle), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home.profile')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });

    testWidgets('home says a required photo is missing, in amber', (
      tester,
    ) async {
      final controller = ProfileController(
        store: MemoryProfileStore(
          StudentProfile(
            record: _record,
            lastName: 'Santos',
            photoRequired: true,
          ),
        ),
        repository: _FakePhotos(),
      );
      await controller.load();

      await tester.pumpWidget(home(controller));
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.nudgeRequiredTitle), findsOneWidget);
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(
        320,
        640,
      );
      final controller = ProfileController(
        store: MemoryProfileStore(_kept(photo: _oldPhoto)),
        repository: _FakePhotos(),
      );
      await controller.load();

      await tester.pumpWidget(app(ProfilePage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(home(controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the app, My Profile plays its own splash first', (
      tester,
    ) async {
      await tester.pumpWidget(
        BccSasqrApp(
          roleStore: MemoryRoleStore(AppRole.student),
          photoRepository: _FakePhotos(),
          speech: const SilentSpeechService(),
          showSplash: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.profile')));
      // The new route's first frame is laid out offstage, for heroes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.byType(ProfileSplash), findsOneWidget);
      expect(find.text(ProfileStrings.splashTagline), findsOneWidget);
      expect(find.text(ProfileStrings.stepScanner), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(ProfileSplash), findsNothing);
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });
}
