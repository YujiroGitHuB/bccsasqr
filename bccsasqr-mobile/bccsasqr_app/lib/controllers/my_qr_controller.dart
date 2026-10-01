import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/student_profile.dart';
import '../services/saved_qr_store.dart';
import '../services/student_repository.dart';
import 'profile_controller.dart';

/// Where the student's own QR code stands, for Home's card.
enum MyQrStatus {
  /// The store has not answered yet.
  loading,

  /// No one is set up on this phone — Home offers My Profile.
  noProfile,

  /// The code is on the phone, ready to show.
  ready,

  /// The server will not issue one until the terms are accepted — once, in
  /// My QR Code.
  needsTerms,

  /// No code on the phone, and the server could not be asked — offline, or
  /// the generator closed.
  unavailable,
}

/// The QR code of the student this phone is set up for — what Home shows
/// and Show to scanner puts full screen.
///
/// The code is never built here: it is the one the server issued, kept by
/// My QR Code (see [SavedQrStore]). With none kept yet, this asks the server
/// for it once; a student who already accepted the terms on the web gets it
/// at once, and anyone else is sent to My QR Code to accept them.
class MyQrController extends ChangeNotifier {
  MyQrController({
    required ProfileController profile,
    required WatchedSavedQrStore saved,
    required StudentRepository repository,
    DateTime Function()? clock,
  }) : _profile = profile,
       _saved = saved,
       _repository = repository,
       _clock = clock ?? DateTime.now {
    _profile.addListener(_onProfile);
    _saved.addListener(reload);
    _onProfile();
  }

  final ProfileController _profile;
  final WatchedSavedQrStore _saved;
  final StudentRepository _repository;
  final DateTime Function() _clock;

  MyQrStatus _status = MyQrStatus.loading;
  SavedQr? _code;
  String? _message;
  String? _number;
  int _token = 0;
  bool _disposed = false;

  MyQrStatus get status => _status;

  /// The kept code, while [status] is [MyQrStatus.ready].
  SavedQr? get code => _status == MyQrStatus.ready ? _code : null;

  /// What stopped the server answering, for [MyQrStatus.unavailable].
  String? get message => _message;

  /// A new student on the phone, or none: start again for them.
  void _onProfile() {
    if (!_profile.loaded) return;
    final number = _profile.profile?.record.studentNumber.value;
    if (number == _number && _status != MyQrStatus.loading) return;
    _number = number;
    unawaited(reload());
  }

  /// Looks again — after a code was kept, or on a pull from Home.
  Future<void> reload() async {
    final StudentProfile? profile = _profile.profile;
    final token = ++_token;

    if (profile == null) {
      _set(MyQrStatus.noProfile, null);
      return;
    }

    final number = profile.record.studentNumber;
    final kept = await _saved.find(number);
    if (_disposed || token != _token) return;
    if (kept != null) {
      _set(MyQrStatus.ready, kept);
      return;
    }

    try {
      final payload = await _repository.issueQrPayload(number);
      if (_disposed || token != _token) return;
      final issued = SavedQr(
        record: profile.record,
        payload: payload,
        savedAt: _clock(),
      );
      // Kept the way My QR Code keeps one, so it opens offline from now on.
      // Not through the watched store's notice: this is the answer already.
      _set(MyQrStatus.ready, issued);
      await _saved.save(issued);
    } on StudentLookupException catch (e) {
      if (_disposed || token != _token) return;
      if (e.isTermsNotAccepted) {
        _set(MyQrStatus.needsTerms, null);
      } else {
        _set(MyQrStatus.unavailable, null, message: e.message);
      }
    }
  }

  void _set(MyQrStatus status, SavedQr? code, {String? message}) {
    _status = status;
    _code = code;
    _message = message;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profile.removeListener(_onProfile);
    _saved.removeListener(reload);
    super.dispose();
  }
}
