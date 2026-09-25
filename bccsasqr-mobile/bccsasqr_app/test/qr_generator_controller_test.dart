import 'package:bccsasqr_app/controllers/qr_generator_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/qr_payload.dart';
import 'package:bccsasqr_app/models/record_warning.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/terms_document.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
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
  Future<QrPayload> issueQrPayload(StudentNumber number) async {
    if (requireAcceptance && !accepted) {
      throw const StudentLookupException(
        'Accept the terms first.',
        code: 'terms_not_accepted',
      );
    }
    // What the real API encodes: the bare student number, nothing else.
    return QrPayload(
      data: number.value,
      details: const [],
      fileName: '${number.value}_qr.png',
    );
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

/// Writes down what would have been said; `null` stands for a stop.
class _RecordingSpeech implements SpeechService {
  final said = <String?>[];

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async => said.add(null);
}

QrGeneratorController build(
  StudentRepository repo, {
  SpeechService speech = const SilentSpeechService(),
}) => QrGeneratorController(
  repository: repo,
  speech: speech,
  debounce: Duration.zero,
);

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

  group('the voice reads what the screen shows', () {
    test('a found record: checking, then the verified badge', () async {
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(result: _known), speech: voice);

      c.onStudentNumberChanged('019-464');
      await c.verifyNow();

      expect(voice.said, [AppStrings.verifying, AppStrings.verifiedBadge]);
    });

    test('a warning card is read after the badge', () async {
      const photo = RecordWarning(
        code: 'photo_missing',
        message: 'You need to upload your photo first.',
      );
      final record = StudentRecord(
        studentNumber: _known.studentNumber,
        fullName: _known.fullName,
        course: _known.course,
        section: _known.section,
        warnings: const [photo],
      );
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(result: record), speech: voice);

      c.onStudentNumberChanged('019-464');
      await c.verifyNow();

      expect(
        voice.said.last,
        'Record verified. You need to upload your photo first.',
      );
    });

    test('an unmatched number reads the not-found line', () async {
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(result: null), speech: voice);

      c.onStudentNumberChanged('021-999');
      await c.verifyNow();

      expect(voice.said.last, AppStrings.errorNotFound);
      expect(voice.said.last, c.errorMessage);
    });

    test('a failure reads the message on screen', () async {
      final voice = _RecordingSpeech();
      final c = build(
        _FakeRepository(
          throws: const StudentLookupException('Too many lookups.'),
        ),
        speech: voice,
      );

      c.onStudentNumberChanged('019-464');
      await c.verifyNow();

      expect(voice.said.last, 'Too many lookups.');
      expect(voice.said.last, c.errorMessage);
    });

    test('a malformed number is read out on submit, not while typing', () async {
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(result: _known), speech: voice);

      c.onStudentNumberChanged('19-46');
      expect(voice.said, isEmpty, reason: 'still typing — stay quiet');

      await c.verifyNow();
      expect(voice.said, [AppStrings.errorFormat]);
    });

    test('submitting an empty field reads its prompt', () async {
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(), speech: voice);

      await c.verifyNow();

      expect(voice.said, [AppStrings.errorEmpty]);
    });

    test('clearing the field and starting over both stop the voice', () {
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(result: _known), speech: voice);

      c.onStudentNumberChanged('');
      c.reset();

      expect(voice.said, [null, null]);
    });

    test('opening How this works reads its text; closing stops', () {
      final voice = _RecordingSpeech();
      final c = build(_FakeRepository(), speech: voice);

      c.onInstructionsToggled(true);
      c.onInstructionsToggled(false);

      expect(voice.said, [AppStrings.howThisWorksBody, null]);
    });
  });

  group('forSpeech keeps the words and fixes the pronunciation', () {
    test('the format hint', () {
      expect(
        forSpeech(AppStrings.errorFormat),
        'That does not look right. Use year, Registration number, '
        'for example 0 1 9, dash, 4 6 4.',
      );
    });

    test('a four-digit registration number', () {
      expect(forSpeech('Try 025-1023.'), 'Try 0 2 5, dash, 1 0 2 3.');
    });

    test('technical detail in trailing brackets is not read', () {
      expect(
        forSpeech(
          'Could not reach the records service. '
          '(ClientException: Failed host lookup (OS Error: 7))',
        ),
        'Could not reach the records service.',
      );
    });

    test('plain text passes through', () {
      expect(
        forSpeech(AppStrings.howThisWorksBody),
        AppStrings.howThisWorksBody,
      );
    });
  });
}
