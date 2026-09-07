/// User-facing copy, kept in one place so the views hold layout only.
abstract final class AppStrings {
  static const String appTitle = 'BCC SASQR Code Generator';
  static const String appTagline =
      'Look up your record and generate the QR code used for attendance.';

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

  static const String emptyQrTitle = 'Nothing to show yet';
  static const String emptyQrBody =
      'Enter your student number and accept the terms — your QR code will '
      'appear here.';

  static const String verifying = 'Checking the enrolment list…';
  static const String verifiedBadge = 'Record verified';

  static const String errorEmpty = 'Enter your student number to continue.';
  static const String errorFormat =
      'That does not look right. Use YEAR-Registration No., e.g. 019-464.';
  static const String errorNotFound =
      'No verified record matches that student number.';
  static const String errorLookupFailed =
      'We could not reach the records service. Try again in a moment.';
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
