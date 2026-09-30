import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/offline_scan.dart';
import '../models/scanner_models.dart';

/// What the scanner keeps on the phone for when there is no internet:
///
/// * the scans made offline, until the server has answered for each —
///   the one thing here that must survive the app being closed, so each is
///   written the moment it is made;
/// * each subject's class list, to check an offline scan against;
/// * the account and subjects last loaded, so a saved sign-in still opens
///   the scanner with no signal.
abstract interface class OfflineScanStore {
  /// Every scan kept under [userId], oldest first — waiting and refused alike.
  Future<List<PendingScan>> scans(int userId);

  /// Adds [scan], or replaces the one with its id (to record a refusal).
  Future<void> put(PendingScan scan);
  Future<void> remove(Iterable<String> ids);

  Future<SubjectRoster?> roster(int userId, String subjectCode);
  Future<void> saveRoster(int userId, SubjectRoster roster);

  Future<SubjectList?> session();
  Future<void> saveSession(SubjectList session);

  /// Drops the class lists and the session — on sign-out. The scans stay:
  /// they are sent the next time that account signs in.
  Future<void> forget();
}

/// A SQLite file in the app's own storage, through sqflite.
class SqfliteOfflineScanStore implements OfflineScanStore {
  /// [factory] and [path] are for the tests, which run it on the desktop.
  SqfliteOfflineScanStore({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _path = path;

  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _db;

  Future<Database> get _open => _db ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final path =
        _path ?? '${await _factory.getDatabasesPath()}/offline_scans.db';
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          // Each row is the model's own JSON; only what is searched on has a
          // column.
          await db.execute('''
            CREATE TABLE scans (
              id         TEXT    PRIMARY KEY,
              user_id    INTEGER NOT NULL,
              scanned_ms INTEGER NOT NULL,
              data       TEXT    NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE rosters (
              user_id      INTEGER NOT NULL,
              subject_code TEXT    NOT NULL,
              data         TEXT    NOT NULL,
              PRIMARY KEY (user_id, subject_code)
            )''');
          await db.execute('''
            CREATE TABLE session (
              id   INTEGER PRIMARY KEY CHECK (id = 1),
              data TEXT    NOT NULL
            )''');
        },
      ),
    );
  }

  @override
  Future<List<PendingScan>> scans(int userId) async {
    final rows = await (await _open).query(
      'scans',
      columns: ['data'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'scanned_ms, id',
    );
    return [
      for (final row in rows) ?_decode(row['data'], PendingScan.fromJson),
    ];
  }

  @override
  Future<void> put(PendingScan scan) async {
    await (await _open).insert('scans', {
      'id': scan.id,
      'user_id': scan.userId,
      'scanned_ms': scan.scannedAt.millisecondsSinceEpoch,
      'data': jsonEncode(scan.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (await _open).delete(
      'scans',
      where: 'id IN (${List.filled(list.length, '?').join(', ')})',
      whereArgs: list,
    );
  }

  @override
  Future<SubjectRoster?> roster(int userId, String subjectCode) async {
    final rows = await (await _open).query(
      'rosters',
      columns: ['data'],
      where: 'user_id = ? AND subject_code = ?',
      whereArgs: [userId, subjectCode],
    );
    return rows.isEmpty
        ? null
        : _decode(rows.first['data'], SubjectRoster.fromJson);
  }

  @override
  Future<void> saveRoster(int userId, SubjectRoster roster) async {
    await (await _open).insert('rosters', {
      'user_id': userId,
      'subject_code': roster.subjectCode,
      'data': jsonEncode(roster.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<SubjectList?> session() async {
    final rows = await (await _open).query('session', columns: ['data']);
    return rows.isEmpty ? null : _decode(rows.first['data'], _sessionFromJson);
  }

  @override
  Future<void> saveSession(SubjectList session) async {
    await (await _open).insert('session', {
      'id': 1,
      'data': jsonEncode({
        'user': session.user.toJson(),
        'subjects': [for (final s in session.subjects) s.toJson()],
        'date': session.date,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> forget() async {
    final db = await _open;
    await db.transaction((txn) async {
      await txn.delete('rosters');
      await txn.delete('session');
    });
  }

  static SubjectList _sessionFromJson(Map<String, dynamic> json) {
    final subjects = json['subjects'];
    return (
      user: ScannerUser.fromJson(json['user'] as Map<String, dynamic>),
      subjects: [
        if (subjects is List)
          for (final s in subjects)
            if (s is Map<String, dynamic>) ScanSubject.fromJson(s),
      ],
      date: json['date'] as String? ?? '',
    );
  }

  /// One unreadable row is skipped, not the lot.
  static T? _decode<T>(
    Object? raw,
    T Function(Map<String, dynamic> json) read,
  ) {
    if (raw is! String) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? read(json) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Keeps it all for the life of the object: the tests, and demo mode, whose
/// scans never leave the phone anyway.
class MemoryOfflineScanStore implements OfflineScanStore {
  final Map<String, PendingScan> kept = {};
  final Map<(int, String), SubjectRoster> rosters = {};
  SubjectList? saved;

  @override
  Future<List<PendingScan>> scans(int userId) async =>
      kept.values.where((s) => s.userId == userId).toList()
        ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));

  @override
  Future<void> put(PendingScan scan) async => kept[scan.id] = scan;

  @override
  Future<void> remove(Iterable<String> ids) async {
    for (final id in ids) {
      kept.remove(id);
    }
  }

  @override
  Future<SubjectRoster?> roster(int userId, String subjectCode) async =>
      rosters[(userId, subjectCode)];

  @override
  Future<void> saveRoster(int userId, SubjectRoster roster) async =>
      rosters[(userId, roster.subjectCode)] = roster;

  @override
  Future<SubjectList?> session() async => saved;

  @override
  Future<void> saveSession(SubjectList session) async => saved = session;

  @override
  Future<void> forget() async {
    rosters.clear();
    saved = null;
  }
}
