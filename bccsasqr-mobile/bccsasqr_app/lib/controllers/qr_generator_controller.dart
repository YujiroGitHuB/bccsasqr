import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/student_number.dart';
import '../models/qr_payload.dart';
import '../models/student_record.dart';
import '../models/terms_document.dart';
import '../services/student_repository.dart';

/// Where the lookup half of the form currently stands.
enum LookupStatus { idle, verifying, verified, notFound, failed }

/// Owns every piece of mutable state on the generator screen and all the rules
/// that decide what the view may show. The widgets read this and render; they
/// never decide anything themselves.
class QrGeneratorController extends ChangeNotifier {
  QrGeneratorController({
    required StudentRepository repository,
    this.debounce = const Duration(milliseconds: 400),
  }) : _repository = repository;

  final StudentRepository _repository;

  /// How long typing must pause before a lookup fires.
  final Duration debounce;

  Timer? _debounceTimer;
  int _lookupToken = 0;
  bool _disposed = false;

  String _input = '';
  LookupStatus _status = LookupStatus.idle;
  StudentRecord? _record;
  String? _errorMessage;
  bool _termsAccepted = false;
  QrPayload? _payload;
  bool _generating = false;
  bool _exporting = false;

  // ---------------------------------------------------------------- getters

  String get input => _input;
  LookupStatus get status => _status;
  StudentRecord? get record => _record;
  String? get errorMessage => _errorMessage;
  bool get termsAccepted => _termsAccepted;
  QrPayload? get payload => _payload;
  bool get isGenerating => _generating;
  bool get isExporting => _exporting;

  bool get isVerifying => _status == LookupStatus.verifying;
  bool get isVerified => _status == LookupStatus.verified && _record != null;
  bool get hasQrCode => _payload != null;

  /// The generate button only unlocks once the record is real *and* the
  /// student has accepted the terms.
  bool get canGenerate =>
      isVerified && _termsAccepted && !_generating && !hasQrCode;

  /// Label shown on the primary button for the current state.
  String get primaryActionLabel {
    if (_generating) return AppStrings.actionGenerating;
    if (hasQrCode) return AppStrings.actionDownload;
    if (isVerified && _termsAccepted) return AppStrings.actionGenerate;
    return AppStrings.actionVerifyFirst;
  }

  bool get isPrimaryActionEnabled => hasQrCode ? !_exporting : canGenerate;

  // ---------------------------------------------------------------- intents

  /// Called on every keystroke. Clears any generated code, then schedules a
  /// debounced lookup so we do not hit the repository per character.
  void onStudentNumberChanged(String value) {
    _input = value;
    _payload = null;
    _errorMessage = null;
    _record = null;
    _debounceTimer?.cancel();

    if (value.trim().isEmpty) {
      _status = LookupStatus.idle;
      notifyListeners();
      return;
    }

    if (!StudentNumber.isValid(value)) {
      // Partially typed numbers are not an error yet — stay quiet until the
      // shape is complete.
      _status = LookupStatus.idle;
      notifyListeners();
      return;
    }

    _status = LookupStatus.verifying;
    notifyListeners();
    _debounceTimer = Timer(debounce, () => verifyNow());
  }

  /// Runs the lookup immediately (keyboard "done", or a retry tap).
  Future<void> verifyNow() async {
    _debounceTimer?.cancel();
    final number = StudentNumber.tryParse(_input);

    if (number == null) {
      _record = null;
      _status = LookupStatus.idle;
      _errorMessage = _input.trim().isEmpty
          ? AppStrings.errorEmpty
          : AppStrings.errorFormat;
      notifyListeners();
      return;
    }

    final token = ++_lookupToken;
    _status = LookupStatus.verifying;
    _errorMessage = null;
    notifyListeners();

    try {
      final found = await _repository.findByStudentNumber(number);
      // Drop the reply if newer input has already superseded this lookup.
      if (_disposed || token != _lookupToken) return;

      if (found == null) {
        _record = null;
        _status = LookupStatus.notFound;
        _errorMessage = AppStrings.errorNotFound;
      } else {
        _record = found;
        _status = LookupStatus.verified;
        _errorMessage = null;
      }
    } on StudentLookupException catch (e) {
      if (_disposed || token != _lookupToken) return;
      _record = null;
      _status = LookupStatus.failed;
      _errorMessage = e.message;
    } catch (_) {
      if (_disposed || token != _lookupToken) return;
      _record = null;
      _status = LookupStatus.failed;
      _errorMessage = AppStrings.errorLookupFailed;
    }
    notifyListeners();
  }

  /// The Terms and Conditions to show before the box is ticked. Fetched
  /// rather than bundled: raising the version on the server must reach the app
  /// without a release.
  Future<TermsDocument> loadTerms() => _repository.fetchTerms();

  void setTermsAccepted(bool accepted) {
    if (_termsAccepted == accepted) return;
    _termsAccepted = accepted;
    if (!accepted) _payload = null;
    notifyListeners();

    // Recorded in the same table the web app writes to, so a student who
    // accepted in the browser is not asked twice and the school keeps one
    // history instead of two.
    //
    // Fire-and-forget on purpose: a failed log must not stand between a
    // student and their QR — the web page takes the same view — and
    // [generate] tries again if the server turns out to disagree.
    if (accepted) unawaited(_recordAcceptance());
  }

  Future<void> _recordAcceptance() async {
    final number = _record?.studentNumber;
    if (number == null) return;

    try {
      await _repository.acceptTerms(number);
    } on StudentLookupException {
      // Swallowed by design — see the note above.
    }
  }

  /// Asks the server for the string to encode. Guarded by [canGenerate].
  ///
  /// The app does NOT build the payload itself; see models/qr_payload.dart for
  /// why that would produce codes the attendance scanner refuses.
  Future<void> generate() async {
    if (!canGenerate) return;

    final record = _record!;
    _generating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _issuePayload(record.studentNumber);
      if (_disposed) return;
      _payload = QrPayload.issued(record, data);
    } on StudentLookupException catch (e) {
      if (_disposed) return;
      _payload = null;
      _errorMessage = e.message;
    } catch (_) {
      if (_disposed) return;
      _payload = null;
      _errorMessage = AppStrings.errorGenerateFailed;
    }

    _generating = false;
    notifyListeners();
  }

  /// One retry, for the one failure worth handling rather than showing.
  ///
  /// The acceptance is sent without blocking the UI, so on a slow connection
  /// the student can reach Generate before it lands. Sending it again costs a
  /// round trip; making them tick the box twice costs their patience.
  Future<String> _issuePayload(StudentNumber number) async {
    try {
      return await _repository.issueQrPayload(number);
    } on StudentLookupException catch (e) {
      if (!e.isTermsNotAccepted) rethrow;
      await _repository.acceptTerms(number);
      return _repository.issueQrPayload(number);
    }
  }

  void setExporting(bool value) {
    if (_exporting == value) return;
    _exporting = value;
    notifyListeners();
  }

  /// Returns the form to its opening state.
  void reset() {
    _debounceTimer?.cancel();
    _lookupToken++;
    _input = '';
    _status = LookupStatus.idle;
    _record = null;
    _errorMessage = null;
    _termsAccepted = false;
    _payload = null;
    _generating = false;
    _exporting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
