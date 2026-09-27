import 'package:flutter/material.dart';

import '../../models/whats_new.dart';

/// The app's What's New — only what changed in My QR Code, My Attendance and
/// the Attendance Scanner. The web system keeps its own, fuller changelog in
/// `includes/whats_new.php`; this one is written for the person holding the
/// phone, so it leaves out the admin pages and the download page.
///
/// Bundled rather than fetched: it describes the build that is installed, and
/// it reads the same offline.
///
/// ── Adding a release ──────────────────────────────────────────────────
/// Put the newest one FIRST, then raise [version] to its `id`. The version is
/// what tells a phone it has not seen this release yet: the home screen shows
/// the "New in this update" card and the dot once, until the page is opened.
/// A release added to again on the same day takes a `.2`, `.3` suffix, as on
/// the web — leaving [version] alone ships the entry silently, which is right
/// for a typo fix.
abstract final class WhatsNewLog {
  static const String version = '2026-09-27.3';

  static const List<WhatsNewRelease> releases = [
    WhatsNewRelease(
      id: '2026-09-27',
      icon: Icons.qr_code_scanner_rounded,
      title: 'The scanner and your attendance, in the app',
      summary:
          'Instructors can now scan attendance with the app, and students can '
          'check their own attendance right beside their QR code. The app '
          'asks whether you are a student or an instructor, and shows each '
          'only their own side. The scanner can be locked with your '
          'fingerprint, and it shows each code it reads in green.',
      items: [
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.switch_account_outlined,
          title: 'Student or instructor? The app asks once',
          text:
              'The first time it opens, the app asks **Who is using this '
              'phone?** Pick **I\'m a student** and you see only **My QR '
              'Code** and **My Attendance** — nothing of the scanner. Picked '
              'the wrong one? **Settings → Role** asks again.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.call_to_action_outlined,
          title: 'Scanner, QR code and attendance on one bar',
          text:
              'Pick **I\'m an instructor** and sign in, and a bar along the '
              'bottom holds **QR Code**, **Scanner**, **Attendance** and '
              '**Settings**. Nothing of it shows before the sign-in, and '
              'signing out takes it away again; the fingerprint lock covers '
              'all of it, not just the scanner. It opens on the scanner, and '
              'a subject you picked stays picked while you look a student up '
              'on another tab — the camera switches off until you come back.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan attendance with the app',
          text:
              'Choose **I\'m an instructor** and sign in with the email and '
              'password you use on the web system — the phone keeps you '
              'signed in. Pick a subject and the camera starts; flip **Late '
              'marking** on once class has begun. Each scan shows the '
              'student\'s photo, beeps, buzzes and reads the name aloud, and '
              'lands in the same **Attendance List** as the web scanner. The '
              'screen stays on while the camera is running.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.tracker,
          icon: Icons.event_available_rounded,
          title: 'Check your own attendance',
          text:
              'Tap **My Attendance** and type your student number. You see '
              'how many days you were marked present, in how many subjects, '
              'the last day you attended, and every subject with its dates, '
              'times and any **Late** mark. It reads the same records as the '
              'web Attendance Tracker, so the two always agree.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.fingerprint_rounded,
          title: 'Lock the scanner with your fingerprint',
          text:
              'After you sign in, the app asks **Lock the scanner?** Turn it '
              'on and the scanner opens only with your fingerprint, face, or '
              'the phone\'s PIN or pattern — and asks again after a minute '
              'away from the app. If your finger will not read, tap **Sign in '
              'with password instead**. Turn it on or off any time from your '
              'picture at the top of the scanner.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.center_focus_strong_rounded,
          title: 'A green outline on every code it reads',
          text:
              'The moment the scanner reads a QR, the frame\'s corners turn '
              '**green**, an outline draws itself around the code and a ring '
              'ripples out from the middle. You can see the code was caught '
              'before the student\'s name comes up.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.phonelink_lock_rounded,
          title: 'Lost your phone? Change your password',
          text:
              'Changing your password in **My Profile** on the web system '
              'signs the app out on every phone at once, so a lost phone '
              'cannot keep scanning under your name.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.volume_off_rounded,
          title: 'Quiet scanning for a quiet room',
          text:
              'Turn the scanner\'s **Sound**, **Vibration** or **Voice** off '
              'one by one in **Settings** — the tab at the bottom, or tap '
              'your picture in the scanner.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.flashlight_on_rounded,
          title: 'The flashlight no longer covers the frame',
          text:
              'The flashlight button sat on a corner of the scan frame, right '
              'where the QR goes. It is now under the camera, beside the '
              '**Status** line, and lights up while the torch is on.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.waving_hand_outlined,
          title: 'The scanner greets you',
          text:
              'Opening the scanner plays a short animation while it checks '
              'your sign-in. Already signed in, it says **Welcome back** and '
              'goes straight to the camera.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.qr_code_2_rounded,
          title: 'My QR Code shows the steps first',
          text:
              'A short opening screen builds a QR code dot by dot and shows '
              'the three steps — **Student no.**, **Verify**, **Save QR** — '
              'so you know what comes next before the form opens.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.fixed,
          area: WhatsNewArea.scanner,
          icon: Icons.replay_rounded,
          title: 'The scanner says “Already marked” again',
          text:
              'Showing a student\'s QR a second time, or leaving it in front '
              'of the camera, got no answer at all. The scanner now checks '
              'the code again after two and a half seconds and says '
              '**Already marked today.**',
          link: false,
        ),
      ],
    ),
    WhatsNewRelease(
      id: '2026-09-25',
      icon: Icons.phone_android_rounded,
      title: 'My QR Code, as an Android app',
      summary:
          'The QR generator is now an app. It makes the very same code as the '
          'web page, so the scanner treats both alike, and it talks you '
          'through each step.',
      items: [
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.qr_code_2_rounded,
          title: 'Make and save your QR on your phone',
          text:
              'Type your student number, accept the terms, and tap '
              '**Download QR Code** to save it on the phone — the same code '
              'the web page makes, down to the last square.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.no_photography_outlined,
          title: 'A warning when your photo is missing',
          text:
              'The scanner will not record a student with no photo on file. '
              'If yours is missing, the app says so as soon as your record is '
              'found, with a button to upload one — so it is fixed at home, '
              'not at the classroom door.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.record_voice_over_outlined,
          title: 'It reads each step aloud',
          text:
              'Like the web page, the app says what is on the screen as it '
              'appears: that it is **checking** your number, whether your '
              'record was **verified** or **not found**, and the missing '
              'photo warning. Turn **Voice** off in Settings if you would '
              'rather it stayed quiet.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.refresh_rounded,
          title: 'A dropped signal is not a dead end',
          text:
              'When the connection drops, a **Try again** button appears '
              'under the message, and you can pull the screen down to check '
              'again — which also clears the photo warning once you have '
              'uploaded your photo.',
        ),
      ],
    ),
  ];
}
