/// Who this phone is for, picked on the first launch. It decides what the app
/// shows, not what it allows: the scanner still asks an instructor to sign
/// in, whichever role the phone was set to.
enum AppRole {
  /// My QR Code and My Attendance, on the home screen. No scanner anywhere.
  student,

  /// My QR Code, the scanner and My Attendance, on a bottom bar.
  instructor,
}
