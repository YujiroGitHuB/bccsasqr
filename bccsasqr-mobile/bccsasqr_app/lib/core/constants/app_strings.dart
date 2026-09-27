/// User-facing copy, kept in one place so the views hold layout only.
abstract final class AppStrings {
  /// The app's name: under the home-screen icon (AndroidManifest.xml,
  /// Info.plist) and in the recent-apps switcher. Short enough that no
  /// launcher cuts it off.
  static const String appName = 'BCC SASQR';

  /// The heading on the generator page, where there is room to say what it is.
  static const String appTitle = 'BCC SASQR Code Generator';

  static const String splashBrand = 'BCC ';
  static const String splashBrandAccent = 'SASQR';
  static const String splashTagline = 'QR CODE GENERATOR & SCANNER';
  static const String splashFooter = 'Binalatongan Community College';
  static const String splashSemantics = 'BCC SASQR is starting';
  static const String appTagline =
      'Look up your record and generate the QR code used for attendance.';

  // The opening screen: which half of the app to open.
  static const String homeHeading = 'WHAT WOULD YOU LIKE TO DO?';
  static const String homeStudentTitle = 'My QR Code';
  static const String homeStudentBody =
      'For students — look up your record and save the QR code you show '
      'at attendance.';
  static const String homeScannerTitle = 'Attendance Scanner';
  static const String homeScannerBody =
      'For instructors — sign in and scan student QR codes to record '
      'attendance.';
  static const String homeBack = 'Home';

  static const String chipVerified = 'Verified records only';
  static const String chipFreeDownload = 'Free download';

  static const String detailsHeading = 'YOUR DETAILS';
  static const String qrHeading = 'YOUR QR CODE';

  static const String howThisWorks = 'How this works';
  static const String howThisWorksBody =
      'Type the student number printed on your registration form. We match it '
      'against the verified enrolment list, then build a QR code that the '
      'attendance scanner can read. Nothing is shared until you agree to the '
      'terms.';

  static const String studentNumberLabel = 'Student Number';
  static const String studentNumberFormat =
      'Format: YEAR-Registration No. — e.g. 019-464 or 025-1023';
  static const String studentNumberHint = '019-464';

  static const String fieldName = 'NAME';
  static const String fieldCourse = 'COURSE';
  static const String fieldSection = 'SECTION';
  static const String emptyValue = '—';

  static const String agreePrefix = 'I agree to the ';
  static const String termsLink = 'Terms and Conditions';

  static const String actionVerifyFirst = 'Verify First';
  static const String actionGenerate = 'Generate QR Code';
  static const String actionGenerating = 'Generating…';
  static const String actionDownload = 'Download QR Code';
  static const String actionReset = 'Start over';
  static const String actionRetry = 'Try again';

  static const String emptyQrTitle = 'Nothing to show yet';
  static const String emptyQrBody =
      'Enter your student number and accept the terms — your QR code will '
      'appear here.';

  /// Said aloud while the field's spinner turns.
  static const String verifying = 'Checking the enrolment list…';
  static const String verifiedBadge = 'Record verified';

  static const String errorEmpty = 'Enter your student number to continue.';
  static const String errorFormat =
      'That does not look right. Use YEAR-Registration No., e.g. 019-464.';
  static const String errorNotFound =
      'No verified record matches that student number.';
  static const String errorLookupFailed =
      'We could not reach the records service. Try again in a moment.';
  static const String demoModeTitle = 'Demo mode — not connected';
  static const String demoModeBody =
      'This build has no API_BASE_URL, so it is reading four bundled sample '
      'records instead of the enrolment list on the server. A real student '
      'number will report "not found" here.';
  static const String demoModeNumbers = 'Numbers that work:';

  static const String errorGenerateFailed =
      'Could not generate your QR code. Try again in a moment.';

  static const String downloadSuccess = 'QR code saved and ready to share.';
  static const String downloadFailure = 'Could not save the QR code.';

  static const String footerRights =
      '© 2026 Binalatongan Community College. All rights reserved.';
  static const String footerDeveloper = 'Developed by ';
  static const String footerDeveloperName = 'Lx';

  static const String termsTitle = 'Terms and Conditions';
  static const String termsClose = 'Close';
  static const String termsAccept = 'I Agree';
  static const String termsLoadFailed =
      'Could not load the terms. Check your connection and try again.';

  static const String developerUrl = 'https://github.com/';
}

/// The scanner's copy. Where the web scanner (Qrscanner/js/scriptV3.js) says
/// something, this says the same words — an instructor who uses both should
/// not have to learn two vocabularies, and the voice lines match its
/// `TTSManager.speak` calls.
abstract final class ScannerStrings {
  static const String title = 'BCC SASQR Scanner';
  static const String subtitle = 'QR attendance capture';

  // Sign-in
  static const String signInHeading = 'Instructor sign-in';
  static const String signInBody =
      'Use the same email and password you use on the web system. You stay '
      'signed in on this phone until you sign out.';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Password';
  static const String showPassword = 'Show password';
  static const String hidePassword = 'Hide password';
  static const String signIn = 'Sign in';
  static const String signingIn = 'Signing in…';
  static const String signOut = 'Sign out';
  static const String signOutConfirmTitle = 'Sign out of the scanner?';
  static const String signOutConfirmBody =
      'You will need your email and password to scan on this phone again.';
  static const String cancel = 'Cancel';
  static const String errorCredentialsEmpty = 'Enter your email and password.';
  static const String sessionExpired =
      'Your sign-in has expired. Please sign in again.';
  static const String checkingSession = 'Checking your sign-in…';
  static const String unreachableTitle = 'Could not reach the server';
  static const String retry = 'Try again';
  static const String demoSignInHint =
      'Demo mode — any email and password will sign in.';
  static const String demoModeBody =
      'This build has no API_BASE_URL, so scans are kept on this phone only '
      'and never reach the school\'s records. Numbers that work:';

  // Who is scanning
  static const String roleAdmin = 'Admin';
  static const String roleAllSections = 'All sections';
  static const String roleInstructor = 'Instructor';

  // Subject
  static const String subjectLabel = 'Select Your Subject';
  static const String subjectPlaceholder = '-- Select Subject to Scan --';
  static const String subjectSheetTitle = 'Subject to scan';
  static const String selectSubjectFirst = 'Please select a subject first';
  static const String readyToScan = 'Ready to scan';
  static const String noSubjectsTitle = 'No Subjects Assigned';
  static const String noSubjectsBody =
      'You don\'t have any subjects assigned to your account yet. Ask an '
      'administrator to assign one before you can scan.';
  static const String subjectsFailed = 'Could not load your subjects.';

  // Late marking
  static const String lateTitle = 'Late marking';
  static const String lateOff = 'Off — every scan counts as on time';
  static const String lateOn = 'On — every scan is saved as late';
  static const String lateNotChanged = 'Late marking not changed';

  // Camera
  static const String cameraIdle = 'Select a subject to start the camera';
  static const String cameraDenied =
      'The camera is not available. Allow camera access for BCC SASQR in '
      'your phone\'s settings, then open the scanner again.';
  static const String cameraUnsupported =
      'Scanning with the camera works in the Android app. Type a student '
      'number below to try the scanner here.';
  static const String manualEntryLabel = 'Student number';
  static const String manualEntrySubmit = 'Record';

  // Result
  static const String statusLabel = 'Status';
  static const String waiting = 'Waiting...';
  static const String noPhoto = '⚠ No photo — identity not verified';
  static const String lateTag = 'Late';
  static const String scannerLocked =
      'The QR scanner has been closed by the administrator. Please try '
      'again later.';

  // Attendance list
  static const String attendanceHeading = 'ATTENDANCE LIST';
  static const String attendanceEmpty = 'No scans yet today.';
  static const String attendanceSearch = 'Search name, number or subject';
  static const String attendanceNoMatch = 'No scans match your search.';

  // Alerts — the web scanner's SweetAlert titles.
  static const String alertOk = 'OK';
  static const String invalidQrTitle = 'Invalid QR Code';
  static const String invalidQrBody =
      'This QR code is not a valid BCC student QR.';
  static const String notAuthorizedTitle = 'Not Authorized';
  static const String notAuthorizedBody =
      'This subject is not assigned to you.';
  static const String notFoundTitle = 'Student Not Found';
  static const String photoRequiredTitle = 'Student Photo Required';
  static const String notEnrolledTitle = 'Not Enrolled';
  static const String errorTitle = 'Error';

  // Spoken — word for word what the web scanner says.
  static const String sayInvalid = 'Invalid QR Format!';
  static const String sayAlreadyMarked = 'Already marked today.';
  static const String sayNotAuthorized =
      'You are not authorized for this subject.';
  static const String sayNotFound = 'Student not found in database.';
  static const String sayPhotoRequired = 'Student photo required.';
  static const String sayError = 'Error saving attendance.';
  static const String sayNetwork = 'Network error. Please check connection.';
  static const String saySelectSubject = 'Please select a subject first!';
}
