import 'dart:io';

import 'package:bccsasqr_app/models/offline_scan.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/services/offline_scan_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The offline queue's real store, on a SQLite file — what a phone runs,
/// through the desktop's SQLite instead of Android's.
void main() {
  late Directory dir;
  late String path;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('offline_scans');
    path = '${dir.path}/offline_scans.db';
  });

  tearDown(() async {
    await databaseFactoryFfi.deleteDatabase(path);
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      // Windows can hold the file a moment longer; the temp folder is fine.
    }
  });

  SqfliteOfflineScanStore open() =>
      SqfliteOfflineScanStore(factory: databaseFactoryFfi, path: path);

  PendingScan scan(String id, {int userId = 4, int minute = 30}) => PendingScan(
    id: id,
    userId: userId,
    studentNumber: '000-1023',
    subjectCode: 'ELEC2',
    subjectName: 'Multimedia Technologies',
    scannedAt: DateTime(2026, 9, 30, 7, minute),
    late: true,
    name: 'SANTOS, MARIA ISABEL',
    course: 'BSCS',
    section: '2B',
  );

  test('a kept scan is still there when the app opens again', () async {
    await open().put(scan('b', minute: 31));
    await open().put(scan('a', minute: 30));
    await open().put(scan('other', userId: 9));

    final kept = await open().scans(4);
    expect(kept.map((s) => s.id), ['a', 'b'], reason: 'oldest first');
    expect(kept.first.scannedAt, DateTime(2026, 9, 30, 7, 30));
    expect(kept.first.late, isTrue);
    expect(kept.first.name, 'SANTOS, MARIA ISABEL');
  });

  test('a refusal replaces the scan, and removing lets it go', () async {
    final store = open();
    await store.put(scan('a'));
    await store.put(
      scan('a').rejectedWith(
        const ScanRejection(code: 'not_enrolled', message: 'Not enrolled'),
      ),
    );

    final kept = await store.scans(4);
    expect(kept.single.rejection?.code, 'not_enrolled');

    await store.remove(['a']);
    expect(await store.scans(4), isEmpty);
  });

  test('class lists and the session are kept, and forgotten on sign-out '
      '— the scans are not', () async {
    final store = open();
    await store.put(scan('a'));
    await store.saveRoster(
      4,
      const SubjectRoster(
        subjectCode: 'ELEC2',
        date: '2026-09-30',
        photoRequired: true,
        students: {
          '000-1023': RosterStudent(
            studentNumber: '000-1023',
            name: 'SANTOS, MARIA ISABEL',
            hasPhoto: false,
          ),
        },
      ),
    );
    await store.saveSession((
      user: const ScannerUser(
        id: 4,
        name: 'Paolo R. Mendoza',
        email: 'paolo@example.test',
        role: 'instructor',
      ),
      subjects: const [
        ScanSubject(
          code: 'ELEC2',
          name: 'Multimedia Technologies',
          lateMarking: true,
        ),
      ],
      date: '2026-09-30',
    ));

    final again = open();
    final roster = await again.roster(4, 'ELEC2');
    expect(roster?.photoRequired, isTrue);
    expect(roster?.students['000-1023']?.hasPhoto, isFalse);
    expect(await again.roster(9, 'ELEC2'), isNull);

    final session = await again.session();
    expect(session?.user.name, 'Paolo R. Mendoza');
    expect(session?.subjects.single.lateMarking, isTrue);
    expect(session?.date, '2026-09-30');

    await again.forget();
    expect(await again.roster(4, 'ELEC2'), isNull);
    expect(await again.session(), isNull);
    expect(await again.scans(4), hasLength(1));
  });
}
