/// Who this phone is for, picked on the first launch. It decides what the app
/// shows, not what it allows: the scanner still asks an instructor to sign
/// in, whichever role the phone was set to.
enum AppRole {
  /// My QR Code and My Attendance, on the home screen. No scanner anywhere.
  student,

  /// Home, the scanner, the tracker and Settings on a bottom bar, with the
  /// Menu — QR Code, Links and the rest — in the middle of it.
  instructor,
}
