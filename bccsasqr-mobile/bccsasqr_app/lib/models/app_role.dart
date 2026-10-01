/// Who this phone is for, picked on the first launch. It decides what the app
/// shows, not what it allows: the scanner still asks an instructor to sign
/// in, whichever role the phone was set to.
enum AppRole {
  /// My QR Code and My Attendance, on the home screen. No scanner anywhere.
  student,

  /// Home first, then the scanner, QR Code, Links, the tracker and Settings
  /// from the Menu — the one button at the foot of the screen.
  instructor,
}
