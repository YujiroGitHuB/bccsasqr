import 'package:bccsasqr_app/controllers/qr_generator_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/terms_document.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _known = StudentRecord(
  studentNumber: StudentNumber.tryParse('019-464')!,
  fullName: 'Charles Nixon Cayading',
  course: 'BS Information Technology',
  section: 'BSIT 4-A',
);

/// Repository double with no latency, so tests never wait on wall-clock time.
class _FakeRepository implements StudentRepository {
  _FakeRepository({this.result, this.throws, this.requireAcceptance = false});

  final StudentRecord? result;
  final Object? throws;

  /// When true, [issueQrPayload] refuses until [acceptTerms] has run — the
  /// server's actual rule.
  final bool requireAcceptance;

  int calls = 0;
  int acceptCalls = 0;
  bool accepted = false;

  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async {
    calls++;
    if (throws != null) throw throws!;
    return result;
  }

  @override
  Future<String> issueQrPayload(StudentNumber number) async {
    if (requireAcceptance && !accepted) {
      throw const StudentLookupException(
        'Accept the terms first.',
        code: 'terms_not_accepted',
      );
    }
    // What the real API issues: the bare student number, nothing else.
    return number.value;
  }

  @override
  Future<TermsDocument> fetchTerms() async =>
      const TermsDocument(version: 1, text: 'terms');

  @override
  Future<void> acceptTerms(StudentNumber number) async {
    acceptCalls++;
    accepted = true;
  }
}

/// Models the race the retry in the controller exists for: the acceptance
/// fired when the box was ticked has not landed by the time Generate is
/// pressed.
class _LostAcceptanceRepository extends _FakeRepository {
  _LostAcceptanceRepository(StudentRecord record)
    : super(result: record, requireAcceptance: true);

  @override
  Future<void> acceptTerms(StudentNumber number) async {
    acceptCalls++;
    if (acceptCalls > 1) accepted = true;
  }
}

/// A server that keeps refusing — the acceptance never sticks. The controller
/// must give up after its one retry and show what the server said, rather than
/// looping or inventing a code.
class _AlwaysRefusesRepository extends _FakeRepository {
  _AlwaysRefusesRepository(StudentRecord record)
    : super(result: record, requireAcceptance: true);

  @override
  Future<void> acceptTerms(StudentNumber number) async {
    acceptCalls++;
  }
}

QrGeneratorController build(StudentRepository repo) =>
    QrGeneratorController(repository: repo, debounce: Duration.zero);

void main() {
  test('starts idle with nothing filled in', () {
    final c = build(_FakeRepository());
    expect(c.status, LookupStatus.idle);
    expect(c.record, isNull);
    expect(c.canGenerate, isFalse);
    expect(c.primaryActionLabel, AppStrings.actionVerifyFirst);
  });

  test('a complete, matching number verifies the record', () async {
    final repo = _FakeRepository(result: _known);
    final c = build(repo);

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();

    expect(c.isVerified, isTrue);
    expect(c.record?.fullName, 'Charles Nixon Cayading');
    expect(c.errorMessage, isNull);
  });

  test('an unmatched number reports not found without an exception', () async {
    final c = build(_FakeRepository(result: null));

    c.onStudentNumberChanged('021-999');
    await c.verifyNow();

    expect(c.status, LookupStatus.notFound);
    expect(c.errorMessage, AppStrings.errorNotFound);
    expect(c.record, isNull);
  });

  test('a repository failure surfaces its message', () async {
    final c = build(
      _FakeRepository(throws: const StudentLookupException('offline')),
    );

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();

    expect(c.status, LookupStatus.failed);
    expect(c.errorMessage, 'offline');
  });

  test('a partial number does not hit the repository', () async {
    final repo = _FakeRepository(result: _known);
    final c = build(repo);

    c.onStudentNumberChanged('019');
    await Future<void>.delayed(Duration.zero);

    expect(repo.calls, 0);
    expect(c.status, LookupStatus.idle);
  });

  test('generate stays locked until terms are accepted', () async {
    final c = build(_FakeRepository(result: _known));

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    expect(c.canGenerate, isFalse);

    c.setTermsAccepted(true);
    expect(c.canGenerate, isTrue);
    expect(c.primaryActionLabel, AppStrings.actionGenerate);
  });

  test('generate produces a payload carrying the record', () async {
    final c = build(_FakeRepository(result: _known));

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();

    expect(c.hasQrCode, isTrue);
    expect(c.payload!.encode(), contains('019-464'));
    expect(c.primaryActionLabel, AppStrings.actionDownload);
  });

  test('the code carries exactly what the server issued', () async {
    // The attendance scanner tests the decoded text against
    // ^\d{3}-\d{3,4}$ (Qrscanner/js/scriptV3.js) and refuses anything else.
    // An earlier version encoded a JSON envelope here; every code it made
    // would have been rejected at the classroom door.
    final c = build(_FakeRepository(result: _known));

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();

    expect(c.payload!.encode(), '019-464');
  });

  test('ticking the box records the acceptance with the server', () async {
    final repo = _FakeRepository(result: _known);
    final c = build(repo);

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);

    expect(repo.acceptCalls, 1);
  });

  test('generate retries once when the acceptance was lost', () async {
    final repo = _LostAcceptanceRepository(_known);
    final c = build(repo);

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();

    expect(repo.acceptCalls, 2, reason: 'the refusal must trigger one retry');
    expect(c.hasQrCode, isTrue);
    expect(c.errorMessage, isNull);
  });

  test('a server refusal surfaces its message instead of a code', () async {
    final repo = _AlwaysRefusesRepository(_known);
    final c = build(repo);

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();

    expect(c.hasQrCode, isFalse);
    expect(c.errorMessage, 'Accept the terms first.');
    expect(repo.acceptCalls, 2, reason: 'one retry, then stop');
  });

  test('editing the number after generating discards the code', () async {
    final c = build(_FakeRepository(result: _known));

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();
    expect(c.hasQrCode, isTrue);

    c.onStudentNumberChanged('019-465');
    expect(c.hasQrCode, isFalse);
    expect(c.record, isNull);
  });

  test('withdrawing consent discards the code', () async {
    final c = build(_FakeRepository(result: _known));

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();

    c.setTermsAccepted(false);
    expect(c.hasQrCode, isFalse);
  });

  test('reset returns every field to its opening state', () async {
    final c = build(_FakeRepository(result: _known));

    c.onStudentNumberChanged('019-464');
    await c.verifyNow();
    c.setTermsAccepted(true);
    await c.generate();

    c.reset();

    expect(c.input, isEmpty);
    expect(c.status, LookupStatus.idle);
    expect(c.record, isNull);
    expect(c.termsAccepted, isFalse);
    expect(c.hasQrCode, isFalse);
  });

  test('a superseded lookup does not overwrite the newer result', () async {
    // Slow first call, fast second — the stale reply must be dropped.
    final c = build(_FakeRepository(result: _known));

    final first = c.verifyNow();
    c.onStudentNumberChanged('019-464');
    await first;
    await c.verifyNow();

    expect(c.isVerified, isTrue);
  });
}
