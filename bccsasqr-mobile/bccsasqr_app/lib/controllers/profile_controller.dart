import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/student_number.dart';
import '../models/student_profile.dart';
import '../services/photo_repository.dart';
import '../services/profile_store.dart';
import '../services/speech_service.dart';
import '../services/student_repository.dart';

/// What My Profile is waiting on, if anything.
enum ProfileBusy { none, verifying, saving }

/// My Profile's state and rules — the web's photo page
/// (`student/assets/js/script.js`) with a memory: once a student has proved
/// the record is theirs, the phone keeps it, and the home screen shows their
/// face.
///
/// Made once for the whole app, so the home screen and the page share it.
class ProfileController extends ChangeNotifier {
  ProfileController({
    required ProfileStore store,
    required StudentPhotoRepository repository,
    SpeechService speech = const SilentSpeechService(),
  }) : _store = store,
       _repository = repository,
       _speech = speech;

  final ProfileStore _store;
  final StudentPhotoRepository _repository;
  final SpeechService _speech;

  bool _loaded = false;
  StudentProfile? _profile;
  ProfileBusy _busy = ProfileBusy.none;
  String? _error;
  Uint8List? _pending;
  bool _disposed = false;

  // ---------------------------------------------------------------- getters

  /// Whether the store has answered; until then there is nothing to show.
  bool get loaded => _loaded;
  StudentProfile? get profile => _profile;
  ProfileBusy get busy => _busy;
  bool get isVerifying => _busy == ProfileBusy.verifying;
  bool get isSaving => _busy == ProfileBusy.saving;

  /// Why the last verification failed, under the form.
  String? get error => _error;

  /// The photo on its way up — shown in place of the old one while it goes.
  Uint8List? get pendingPhoto => _pending;

  // ---------------------------------------------------------------- intents

  Future<void> load() async {
    final kept = await _store.load();
    if (_disposed) return;
    _profile = kept;
    _loaded = true;
    notifyListeners();
  }

  /// Step 1. True once the record is this phone's.
  Future<bool> verify(String rawNumber, String lastName) async {
    if (_busy != ProfileBusy.none) return false;
    final number = StudentNumber.tryParse(rawNumber);
    final problem = rawNumber.trim().isEmpty
        ? AppStrings.errorEmpty
        : number == null
        ? AppStrings.errorFormat
        : lastName.trim().isEmpty
        ? ProfileStrings.errorLastName
        : null;
    if (problem != null) {
      _fail(problem);
      return false;
    }

    _busy = ProfileBusy.verifying;
    _error = null;
    notifyListeners();
    unawaited(_speech.speak(ProfileStrings.verifying));

    try {
      final owner = await _repository.verifyOwner(number!, lastName.trim());
      final photo = await _download(owner.photoUrl);
      final profile = StudentProfile(
        record: owner.record,
        lastName: lastName.trim(),
        photoUrl: owner.photoUrl,
        photo: photo,
        photoRequired: owner.required,
      );
      await _store.save(profile);
      _profile = profile;
      unawaited(_speech.speak(ProfileStrings.welcome(profile.givenName)));
      return true;
    } on StudentLookupException catch (e) {
      _fail(_messageFor(e));
      return false;
    } finally {
      _busy = ProfileBusy.none;
      if (!_disposed) notifyListeners();
    }
  }

  /// Step 2: [jpeg] becomes this student's photo. Null once it is saved;
  /// otherwise what went wrong, for the island — the old photo stays.
  Future<String?> savePhoto(Uint8List jpeg) async {
    final profile = _profile;
    if (profile == null || _busy != ProfileBusy.none) return null;

    _busy = ProfileBusy.saving;
    _pending = jpeg;
    notifyListeners();

    try {
      final owner = await _repository.uploadPhoto(
        profile.record.studentNumber,
        profile.lastName,
        jpeg,
      );
      final saved = profile.copyWith(
        record: owner.record,
        photoUrl: owner.photoUrl,
        photo: jpeg,
        photoRequired: owner.required,
      );
      await _store.save(saved);
      _profile = saved;
      unawaited(_speech.speak(ProfileStrings.savedTitle));
      return null;
    } on StudentLookupException catch (e) {
      return _messageFor(e);
    } finally {
      _busy = ProfileBusy.none;
      _pending = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Quietly picks up what changed on the server since — a photo uploaded in
  /// the browser, an admin's fix to the name. Offline, the kept copy stands.
  Future<void> refresh() async {
    final profile = _profile;
    if (profile == null || _busy != ProfileBusy.none) return;
    try {
      final owner = await _repository.fetchOwner(profile.record.studentNumber);
      final changed = owner.photoUrl != profile.photoUrl;
      final photo = changed ? await _download(owner.photoUrl) : profile.photo;
      // Replaced meanwhile — a new photo saved, or the profile forgotten.
      if (_disposed || !identical(_profile, profile)) return;
      final fresh = StudentProfile(
        record: owner.record,
        lastName: profile.lastName,
        photoUrl: owner.photoUrl,
        // A new link that would not download keeps the face already here.
        photo: owner.photoUrl == null ? null : photo ?? profile.photo,
        photoRequired: owner.required,
      );
      await _store.save(fresh);
      _profile = fresh;
      notifyListeners();
    } on StudentLookupException {
      // Offline, or the server is busy: the kept copy is still right enough.
    }
  }

  /// "Not you?" — this phone forgets the student. Nothing changes on the
  /// server; the photo stays on their record.
  Future<void> forget() async {
    await _store.clear();
    _profile = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- helpers

  /// The photo's bytes, or null — a picture that will not download is not a
  /// reason to refuse the profile; the link still shows it online.
  Future<Uint8List?> _download(String? url) async {
    if (url == null) return null;
    try {
      return await _repository.downloadPhoto(url);
    } on StudentLookupException {
      return null;
    }
  }

  /// The server's words, except where the limit's "wait a moment" would
  /// undersell fifteen minutes.
  String _messageFor(StudentLookupException e) =>
      e.code == 'rate_limited' ? ProfileStrings.tooManyTries : e.message;

  void _fail(String message) {
    _error = message;
    unawaited(_speech.speak(message));
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
