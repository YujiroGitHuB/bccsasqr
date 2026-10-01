import '../core/utils/student_number.dart';
import '../models/live_update.dart';
import 'student_repository.dart';

/// The student's live feed (`POST /students/{no}/live`): what is new on
/// their record since the phone last looked.
///
/// [lastName] is the proof My Profile took — the feed is counted per
/// student, so it asks for it. Everything that goes wrong raises a
/// [StudentLookupException] carrying the server's `code`.
abstract interface class LiveRepository {
  /// Without [since] — the phone's first look — only where the record
  /// stands, no records.
  Future<LiveUpdate> fetchLive(
    StudentNumber number, {
    required String lastName,
    int? since,
  });
}

/// What runs when no `API_BASE_URL` was supplied at build time. The sample
/// records never change, so there is never anything new.
///
/// Answers at once: a demo has no server to wait for, and a test's pending
/// delay would outlive the page that asked.
class InMemoryLiveRepository implements LiveRepository {
  const InMemoryLiveRepository();

  @override
  Future<LiveUpdate> fetchLive(
    StudentNumber number, {
    required String lastName,
    int? since,
  }) async => const LiveUpdate(cursor: 0, count: 0);
}
