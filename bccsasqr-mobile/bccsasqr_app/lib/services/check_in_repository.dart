import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/student_number.dart';
import '../models/class_link.dart';
import 'student_repository.dart';

/// Check in's server: the class behind a code, and the check-in itself.
///
/// Every refusal is a [StudentLookupException] carrying the server's code —
/// `link_expired`, `already_checked_in`, `device_reuse`, … — and the web
/// form's own words as its message.
abstract interface class CheckInRepository {
  Future<ClassLink> findClass(String code);

  /// Records [number] through [code]. [device] is the token an earlier
  /// answer handed this phone; [onDevice] gets the one to keep from now on,
  /// refusals included.
  Future<CheckInResult> checkIn(
    String code, {
    required StudentNumber number,
    required String lastName,
    String? device,
    void Function(String device)? onDevice,
  });
}

/// The token that makes this phone one device to the server's
/// one-device-one-student rule — the app's counterpart of the web form's
/// signed cookie. Not a secret: copying it to a classmate's phone only makes
/// the two phones one device, which is stricter, not looser.
abstract interface class DeviceTokenStore {
  Future<String?> load();
  Future<void> save(String token);
}

/// The phone's shared preferences. A store that cannot be read is a new
/// device — the server hands out a fresh token, as for a cleared cookie.
class SharedPrefsDeviceTokenStore implements DeviceTokenStore {
  static const String _key = 'checkin_device.v1';

  @override
  Future<String?> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String token) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, token);
    } catch (_) {
      // The next check-in is a new device; the audit trail shows it.
    }
  }
}

/// Keeps it for the life of the object. For tests, and the default.
class MemoryDeviceTokenStore implements DeviceTokenStore {
  MemoryDeviceTokenStore([this.token]);

  String? token;

  @override
  Future<String?> load() async => token;

  @override
  Future<void> save(String token) async => this.token = token;
}

/// What runs when no `API_BASE_URL` was supplied at build time: one class,
/// code `K7P2QX`, that takes each student once a day — so the whole screen
/// can be tried without a server.
class InMemoryCheckInRepository implements CheckInRepository {
  InMemoryCheckInRepository({this.latency = const Duration(milliseconds: 500)});

  final Duration latency;

  /// The demo class's code, for the demo-mode hint.
  static const String sampleCode = 'K7P2QX';

  final Set<String> _checkedIn = {};

  static const ClassLink _class = ClassLink(
    shortCode: sampleCode,
    subjectCode: 'ITE211',
    subjectName: 'Object Oriented Programming',
    section: 'BSIT-2A',
    instructor: 'Sample Instructor',
    closesLabel: '9:00 AM',
    lateOn: true,
    lateLabel: '8:15 AM',
    lateIn: 900,
  );

  @override
  Future<ClassLink> findClass(String code) async {
    await Future<void>.delayed(latency);
    if (code.toUpperCase() != sampleCode) {
      throw const StudentLookupException(
        'This attendance link is not valid.',
        code: 'link_not_found',
      );
    }
    return _class;
  }

  @override
  Future<CheckInResult> checkIn(
    String code, {
    required StudentNumber number,
    required String lastName,
    String? device,
    void Function(String device)? onDevice,
  }) async {
    final link = await findClass(code);
    onDevice?.call(device ?? 'demo-device');
    if (!_checkedIn.add(number.value)) {
      throw StudentLookupException(
        'You have already submitted your attendance for '
        '${link.subjectName} today.',
        code: 'already_checked_in',
      );
    }
    return CheckInResult(
      subject: link.subjectName,
      timeIn: '08:04:12 AM',
      late: false,
      message: 'Attendance submitted successfully for ${link.subjectName}!',
    );
  }
}
