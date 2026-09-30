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

  // The student's opening screen. The instructor's is the bottom bar
  // (NavStrings).
  static const String homeStudentSection = 'FOR STUDENTS';
  static const String homeStudentTitle = 'My QR Code';
  static const String homeStudentBody =
      'Look up your record and save the QR code you show at attendance.';
  static const String homeTrackerTitle = 'My Attendance';
  static const String homeTrackerBody =
      'See how many times you were marked present in each subject.';
  static const String homeBack = 'Home';

  // The top of the student's home screen, by the time of day.
  static const String homeMorning = 'Good morning';
  static const String homeAfternoon = 'Good afternoon';
  static const String homeEvening = 'Good evening';
  static const String homeQuestion = 'What do you need today?';
  static const String homeOpen = 'Open';
  static const String homeHowItWorks = 'HOW IT WORKS';

  // The generator's opening splash: a QR being made, and the three steps.
  static const String generatorSplashTagline = 'QR CODE GENERATOR';
  static const String generatorSplashSemantics =
      'Opening the QR code generator';
  static const String generatorStepNumber = 'Student no.';
  static const String generatorStepVerify = 'Verify';
  static const String generatorStepSave = 'Save QR';

  // The splash after "I'm a student": a student card building itself, and
  // the three things the student side is for.
  static const String studentSplashTagline = 'FOR STUDENTS';
  static const String studentSplashSemantics = 'Opening the student side';
  static const String studentStepSave = 'Save QR';
  static const String studentStepScan = 'Get scanned';
  static const String studentStepCheck = 'See days';

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
      'Format: YEAR-Registration No. — e.g. 019-464 or 000-1023';
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

  /// Offline, with this number's code saved on the phone from before.
  static String offlineCopy(String date) =>
      'Offline — using the QR code saved on this phone on $date. It scans '
      'the same.';

  /// Offline, with nothing saved for this number: said after the reason.
  static const String offlineNoCopy =
      'A QR code made on this phone before opens even without internet.';

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

  /// Under the sign-in form — for the student who tapped "I'm an
  /// instructor" to see what was behind it.
  static const String signInOnlyInstructors =
      'Only instructors with a BCC SASQR account can sign in here.';
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

  // The camera's own switch, for the time between queues.
  static const String cameraStop = 'Stop camera';
  static const String cameraStopHint = 'Turn the camera off until you need it';
  static const String cameraOffTitle = 'Camera is off';
  static const String cameraOffBody =
      'Turn it back on when the next student is ready to scan.';
  static const String cameraStart = 'Turn on camera';
  static const String cameraOffStatus = 'Camera off — turn it on to scan';

  // Result
  static const String statusLabel = 'Status';
  static const String waiting = 'Waiting...';
  static const String noPhoto = '⚠ No photo — identity not verified';
  static const String lateTag = 'Late';
  static const String scannerLocked =
      'The QR scanner has been closed by the administrator. Please try '
      'again later.';

  // Attendance list: the newest few under the camera, the rest in a sheet.
  static const String attendanceHeading = 'ATTENDANCE LIST';
  static const String attendanceEmpty = 'No scans yet today.';
  static const String attendanceSearch = 'Search name, number or subject';
  static const String attendanceNoMatch = 'No scans match your search.';
  static const String attendanceSheetTitle = 'Attendance list';
  static const String attendanceAll = 'All subjects';
  static const String attendanceNoneForSubject =
      'No scans for this subject yet today.';
  static String attendanceViewAll(int n) => 'View all $n';

  // Offline: scans kept on the phone, and sent later.
  static const String savedOffline = 'saved offline';
  static const String pendingTag = 'Pending';
  static const String resultPending = 'Saved on this phone — sends when online';
  static const String offlineTitle = 'Offline — keep scanning';
  static const String offlineBody =
      'Scans are kept on this phone and sent by themselves when the internet '
      'is back.';
  static String pendingTitle(int n) =>
      n == 1 ? '1 scan waiting to be sent' : '$n scans waiting to be sent';
  static const String pendingBody =
      'Kept on this phone. They go out by themselves; tap Send now to try at '
      'once.';
  static String sendingTitle(int n) =>
      n == 1 ? 'Sending 1 scan…' : 'Sending $n scans…';
  static const String sendNow = 'Send now';
  static String syncedTitle(int n) =>
      n == 1 ? '1 offline scan sent' : '$n offline scans sent';
  static const String syncedBody =
      'The scans kept on this phone are now in the records.';
  static String notSavedCountTitle(int n) =>
      n == 1 ? '1 offline scan not saved' : '$n offline scans not saved';
  static const String notSavedCountBody =
      'The server refused them. See why under the Attendance List.';
  static const String seeWhy = 'See why';
  static const String notSavedSheetTitle = 'Offline scans not saved';
  static const String notSavedSheetBody =
      'These were scanned with no internet and refused when they were sent — '
      'the same checks as a live scan. If the student is here, scan them '
      'again.';
  static const String notSavedClear = 'Clear list';
  static String signOutPendingBody(int n) =>
      '${n == 1 ? '1 scan' : '$n scans'} on this phone '
      '${n == 1 ? 'has' : 'have'} not been sent yet. '
      '${n == 1 ? 'It stays' : 'They stay'} here and '
      '${n == 1 ? 'is' : 'are'} sent the next time you sign in with this '
      'account.';

  // Alerts — the web scanner's SweetAlert titles.
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
  static const String saySelectSubject = 'Please select a subject first!';

  // The account sheet behind the avatar.
  static const String account = 'Account';
  static const String settingsTileBody = 'Theme, sound, vibration and voice';

  // The lock: the phone's fingerprint, face or screen lock in front of a
  // saved sign-in.
  static const String lockTitle = 'Scanner locked';
  static const String lockBody =
      'Open it with this phone\'s fingerprint, face or screen lock.';
  static const String lockUnlock = 'Unlock';
  static const String lockUnlockedLabel = 'UNLOCKED';
  static const String lockUsePassword = 'Sign in with password instead';
  static const String lockNotUnlocked =
      'Not unlocked yet. Tap Unlock to try again.';
  static const String lockReason = 'Unlock the attendance scanner';
  static const String lockEnableReason =
      'Confirm it is you to lock the scanner';
  static const String lockLost =
      'This phone\'s screen lock was turned off, so sign in with your '
      'password again.';
  static const String lockOfferTitle = 'Lock the scanner?';
  static const String lockOfferBody =
      'Next time, the scanner opens with this phone\'s fingerprint, face or '
      'screen lock — so nobody else who picks up the phone can scan under '
      'your name. You can turn it off from your picture at the top.';
  static const String lockOfferLater = 'Not now';
  static const String lockOfferOn = 'Turn on';
  static const String lockOn = 'Scanner lock is on';
  static const String lockTile = 'Fingerprint lock';
  static const String lockTileBody = 'Open the scanner with this phone\'s lock';
}

/// What the app says when the phone loses — and gets back — its connection.
abstract final class OfflineStrings {
  static const String title = 'You\'re offline';
  static const String body =
      'Sign-in and look-ups need the internet. QR codes already made on this '
      'phone still open, and the scanner keeps scans until you are back '
      'online.';
  static const String back = 'Back online';
}

/// The Attendance Tracker's copy — the web tracker's (`Tracker/view.php`,
/// `Tracker/js/script.js`) words, including what it says aloud.
abstract final class TrackerStrings {
  static const String title = 'Attendance Tracker';
  static const String tagline =
      'Check how many times you have been marked present in each subject.';

  // The opening splash: a calendar filling with checks, and the three steps.
  static const String splashTagline = 'ATTENDANCE TRACKER';
  static const String splashSemantics = 'Opening the attendance tracker';
  static const String stepNumber = 'Student no.';
  static const String stepSearch = 'Search';
  static const String stepDays = 'Your days';
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

  // A student's phone has no scanner, so only the voice is left to set.
  static const String feedbackStudent = 'READ ALOUD';
  static const String voiceBodyStudent =
      'Read each step aloud in My QR Code and My Attendance';

  static const String role = 'ROLE';

  // An instructor's: who is signed in, and the way out.
  static const String account = 'ACCOUNT';
  static const String signOutBody = 'Sign this phone out of the scanner';

  static const String about = 'ABOUT';
  static const String version = 'Version';
  static const String server = 'Server';
  static const String serverDemo = 'Demo mode — not connected';
  static const String whatsNew = 'What\'s New';
  static const String update = 'Get the latest version';
  static const String updateBody = 'Opens the download page';
  static const String developer = 'Developer';
  static const String tour = 'App tour';
  static const String tourBody = 'The introduction from the first launch';
}

/// The introduction on the first launch, before the student-or-instructor
/// question — and again from Settings → App tour.
abstract final class OnboardingStrings {
  static const String skip = 'Skip';
  static const String next = 'Next';
  static const String start = 'Get started';

  /// Seen again from Settings, the last button closes it.
  static const String done = 'Done';

  static String semantics(int page, int of) => 'Introduction, $page of $of';

  static const String welcomeTitle = 'Welcome to BCC SASQR';
  static const String welcomeBody =
      'Attendance by QR code at Binalatongan Community College — for students '
      'and instructors, in one app.';
  static const String welcomeQr = 'QR code';
  static const String welcomeScan = 'Scan';
  static const String welcomeDays = 'Attendance';

  static const String qrTitle = 'Your QR code, on your phone';
  static const String qrBody =
      'Type your student number once. The app checks it against the '
      'enrolment list and makes your QR code — kept on this phone, so it '
      'opens even without internet.';
  static const String qrChip = 'Opens offline';

  static const String scanTitle = 'Show it, get marked present';
  static const String scanBody =
      'In class, your instructor scans your code. The app beeps, shows your '
      'photo and says your name — and keeps scanning even with no signal.';
  static const String scanChip = 'Marked present';

  static const String daysTitle = 'See every day you were there';
  static const String daysBody =
      'Open My Attendance to see the days you were marked present in each '
      'subject, late marks included.';
  static String daysChip(int n) => n == 1 ? '1 day present' : '$n days present';
}

/// The What's New page and the home screen's card for it. The entries
/// themselves are in whats_new_log.dart.
abstract final class WhatsNewStrings {
  static const String title = 'What\'s New';
  static const String open = 'What\'s New';
  static const String openUnread = 'What\'s New — new in this update';
  static const String intro =
      'What changed in My QR Code, My Attendance and the Attendance Scanner.';
  static const String introStudent =
      'What changed in My QR Code and My Attendance.';

  static const String latest = 'LATEST';

  // The filter along the top.
  static const String filterAll = 'All';
  static const String filterQr = 'QR Code';
  static const String filterTracker = 'Tracker';
  static const String filterScanner = 'Scanner';

  // The chip on each item — the web's New / Improved / Fixed.
  static const String kindAdded = 'NEW';
  static const String kindImproved = 'IMPROVED';
  static const String kindFixed = 'FIXED';

  // The chip naming the part of the app, and the button that opens it.
  static const String areaQr = 'MY QR CODE';
  static const String areaTracker = 'MY ATTENDANCE';
  static const String areaScanner = 'SCANNER';
  static const String openQr = 'Open My QR Code';
  static const String openTracker = 'Open My Attendance';
  static const String openScanner = 'Open the Scanner';

  // The student's home screen card, until the page is opened once. The
  // instructor's bar puts a dot on Settings instead.
  static const String cardTitle = 'New in this update';
  static const String cardBody =
      'See what changed in My QR Code and My Attendance.';
  static const String cardClose = 'Dismiss';

  // The row in Settings → About.
  static const String settingsBody = 'What changed in this version';
}

/// The question on the first launch, and the row in Settings that asks it
/// again.
abstract final class RoleStrings {
  static const String question = 'Who is using this phone?';
  static const String lead = 'Pick one, and the app shows only what is yours.';
  static const String hint = 'You can change this later in Settings.';

  // Under the instructor's card: what is behind it.
  static const String signInChip = 'Sign-in';

  static const String studentTitle = 'I\'m a student';
  static const String studentBody =
      'Save your QR code and check your own attendance.';
  static const String instructorTitle = 'I\'m an instructor';
  static const String instructorBody =
      'Sign in to scan attendance, with the QR generator and the tracker '
      'beside it.';

  // Above the instructor's sign-in form: back to the question.
  static const String signInBack = 'Back';

  // Settings → Role.
  static const String currentStudent = 'Student';
  static const String currentInstructor = 'Instructor';
  static const String switchBody = 'Tap to choose again';
}

/// The instructor's bottom bar.
abstract final class NavStrings {
  static const String qr = 'QR Code';
  static const String scanner = 'Scanner';
  static const String tracker = 'Attendance';
  static const String settings = 'Settings';
  static const String settingsUnread = 'Settings — new in this update';
}

/// The card that opens from Settings → Version.
abstract final class AboutStrings {
  static const String semantics = 'About BCC SASQR';
  static String version(String version) => 'Version $version';
  static String build(String build) => 'build $build';
  static const String updated = 'Last update';
  static const String server = 'Server';
  static const String role = 'Using it as';
  static const String copy = 'Copy details';
  static const String copied = 'Copied';
  static const String done = 'Done';
  static const String demo = 'Demo mode';
}
