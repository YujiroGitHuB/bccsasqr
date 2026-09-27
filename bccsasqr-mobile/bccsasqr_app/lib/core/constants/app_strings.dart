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

  // The opening screen: one section per person, so each finds their own
  // half without reading both cards.
  static const String homeStudentSection = 'FOR STUDENTS';
  static const String homeStudentTitle = 'My QR Code';
  static const String homeStudentBody =
      'Look up your record and save the QR code you show at attendance.';
  static const String homeTrackerTitle = 'My Attendance';
  static const String homeTrackerBody =
      'See how many times you were marked present in each subject.';
  static const String homeInstructorSection = 'FOR INSTRUCTORS';
  static const String homeScannerTitle = 'Attendance Scanner';
  static const String homeScannerBody =
      'Sign in and scan student QR codes to record attendance.';
  static const String homeBack = 'Home';

  // The generator's opening splash: a QR being made, and the three steps.
  static const String generatorSplashTagline = 'QR CODE GENERATOR';
  static const String generatorSplashSemantics =
      'Opening the QR code generator';
  static const String generatorStepNumber = 'Student no.';
  static const String generatorStepVerify = 'Verify';
  static const String generatorStepSave = 'Save QR';

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

  /// The same link as the web footer (System Settings → Developer Link).
  static const String developerUrl = 'https://cncc.vercel.app/';
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

  // The scanner's opening splash, and the welcome after a sign-in.
  static const String splashWord = ' Scanner';
  static const String splashSemantics = 'Opening the attendance scanner';
  static String welcomeBack(String name) => 'Welcome back, $name';
  static const String welcomeLabel = 'SIGNED IN';
  static String welcomeTitle(String name) => 'Welcome, $name';
  static const String welcomeBody = 'Opening the scanner…';
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
  static const String flashlight = 'Flashlight';
  static const String flashlightOn = 'Turn the flashlight on';
  static const String flashlightOff = 'Turn the flashlight off';

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

  // The account sheet behind the avatar.
  static const String account = 'Account';
  static const String settingsTileBody = 'Theme, sound, vibration and voice';
}

/// The Attendance Tracker's copy — the web tracker's (`Tracker/view.php`,
/// `Tracker/js/script.js`) words, including what it says aloud.
abstract final class TrackerStrings {
  static const String title = 'Attendance Tracker';
  static const String tagline =
      'Check how many times you have been marked present in each subject.';
  static const String chipViewOnly = 'View only';
  static const String chipLive = 'Updated live';

  static const String findHeading = 'FIND YOUR RECORD';
  static const String autoSearchHint =
      'The search runs on its own — no need to press anything.';

  static const String placeholderTitle = 'No record shown yet';
  static const String placeholderBody =
      'Enter your student number above to see your attendance per subject.';

  // The three numbers at the top.
  static const String statPresent = 'Days present';
  static const String statSubjects = 'Subjects';
  static const String statLast = 'Last attended';

  static String days(int n) => n == 1 ? '$n day' : '$n days';
  static const String tableDate = 'Date';
  static const String tableTimeIn = 'Time in';
  static String showAll(int n) => 'Show all $n';
  static const String showLess = 'Show less';

  static const String emptyTitle = 'No attendance yet';
  static const String emptyBody =
      'This record exists, but no scan has been logged for it. Your first '
      'scan will show up here.';
  static const String notFoundTitle = 'Student not found';
  static const String notFoundBody =
      'No record matches that student number. Check for a missing dash or a '
      'typo, then try again.';

  // Status lines — shown, and read aloud word for word as the web does.
  static const String searching = 'Searching Student Attendance record';
  static const String loaded = 'Attendance Records loaded successfully!';
  static const String noAttendance =
      'Student found but no attendance records yet.';
  static const String notFound =
      'Student not found. Please check your student number and try again.';
  static const String failed =
      'Could not load the attendance records. Try again in a moment.';
}

/// The Settings screen — the whole app's, reached from the home screen and
/// from the scanner's account sheet.
abstract final class SettingsStrings {
  static const String title = 'Settings';
  static const String open = 'Settings';

  static const String appearance = 'APPEARANCE';
  static const String theme = 'Theme';
  static const String themeHint =
      'System follows your phone — light by day, dark at night if it is set '
      'to switch.';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';

  static const String feedback = 'SCANNER FEEDBACK';
  static const String sound = 'Sound';
  static const String soundBody = 'Beep after every scan';
  static const String vibration = 'Vibration';
  static const String vibrationBody = 'Buzz after every scan';
  static const String voice = 'Voice';
  static const String voiceBody =
      'Read names and messages aloud — scanner, generator and tracker';

  static const String about = 'ABOUT';
  static const String version = 'Version';
  static const String server = 'Server';
  static const String serverDemo = 'Demo mode — not connected';
  static const String update = 'Get the latest version';
  static const String updateBody = 'Opens the download page';
  static const String developer = 'Developer';
}
