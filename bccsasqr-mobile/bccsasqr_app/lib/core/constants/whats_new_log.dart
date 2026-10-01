import 'package:flutter/material.dart';

import '../../models/whats_new.dart';

/// The app's What's New — only what changed in My QR Code, My Attendance, the
/// Attendance Scanner and the attendance links. The web system keeps its own, fuller changelog in
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
  static const String version = '2026-10-01.2';

  static const List<WhatsNewRelease> releases = [
    WhatsNewRelease(
      id: '2026-10-01',
      icon: Icons.grid_view_rounded,
      title: 'Just the Menu button, and straight to Home',
      summary:
          'The bottom of the screen is now only the round Menu button. '
          'Everything is in the Menu, Home included, and each page runs all '
          'the way down under the button. The app opens straight on Home, '
          'and the scanner\'s splash plays when you open the Scanner.',
      items: [
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.qr_code_scanner_rounded,
          title: 'Straight to Home when the app opens',
          text:
              'The scanner\'s splash no longer comes before **Home** when you '
              'open the app — Home opens right after the app\'s own opening '
              'screen. The scanner\'s splash now plays when you first open '
              'the **Scanner**, as **QR Code**, **Attendance** and **Links** '
              'play theirs.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.grid_view_rounded,
          title: 'One Menu button at the bottom',
          text:
              '**Home**, **Scanner**, **Attendance** and **Settings** are no '
              'longer on the bar — they were in the **Menu** already. Only '
              'the round **Menu** button is left at the bottom, and the page '
              'runs all the way down under it, so more of it fits on the '
              'screen. Tap it for any part, **Home** included; the one you '
              'are on is marked. The phone\'s back button still takes you '
              '**Home**.',
          link: false,
        ),
      ],
    ),
    WhatsNewRelease(
      id: '2026-09-30',
      icon: Icons.cloud_off_rounded,
      title: 'Your photo, attendance links, and working offline',
      summary:
          'Students can add their own photo in the app, and are greeted by '
          'name and face on the home screen. Instructors now open on a Home '
          'screen with today\'s scans at a glance and a Menu in the middle '
          'of the bar, and have their attendance links in the app, QR codes '
          'included. The scanner keeps scanning when the signal drops and '
          'sends the scans once you are back online. Your QR code opens with '
          'no internet too. The scanner\'s list is shorter, and its camera '
          'can be switched off between classes.',
      items: [
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.space_dashboard_outlined,
          title: 'Home, with a Menu in the middle',
          text:
              'The app now opens on **Home**: how many you scanned today, on '
              'time and late, each subject with its last scan, and the newest '
              'scans. **Scan now** takes you straight to the scanner. The '
              'round **Menu** button in the middle of the bar opens everything '
              'else — **QR Code**, **Links**, **Attendance**, **Today\'s '
              'scans**, What\'s New, Settings and **Sign out**. **Home**, '
              '**Scanner**, **Attendance** and **Settings** stay on the bar.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.manage_accounts_outlined,
          title: 'Your account is in Settings',
          text:
              'The top of the scanner now shows only its title, so the camera '
              'sits higher on the screen. Who is signed in — your name, role, '
              'subjects and ID — the **Fingerprint lock** switch and '
              '**Sign out** are all in **Settings → Account**.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.profile,
          icon: Icons.account_circle_outlined,
          title: 'Add your photo from the app',
          text:
              'Tap the circle beside the greeting to open **My Profile**. '
              'Enter your student number and last name, then **Take a photo** '
              'or **Choose from gallery**, fit your face inside the circle and '
              'tap **Use photo**. It is the same photo as on the school\'s web '
              'page: your instructor sees it on the scanner from your next '
              'scan. Your face and name now greet you on the home screen too. '
              'If My QR Code says your photo is missing, **Upload your photo** '
              'opens it right here.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.links,
          icon: Icons.link_rounded,
          title: 'Your attendance links, in the app',
          text:
              'The new **Links**, in the **Menu**, has the same attendance '
              'links as the web page, one for each of your classes. Tap **QR code** to show it '
              'full screen for the class — the screen stays on while it is '
              'up — or **Copy** and **Share** to send the link to the group '
              'chat. Set when it closes and when students start counting as '
              'late, or tap **New link** for the next class. A change made '
              'here shows on the web at once, and the other way round.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.cloud_upload_outlined,
          title: 'Keep scanning with no internet',
          text:
              'No signal in the room? Keep scanning. Each scan is saved on '
              'this phone at once, still beeps and says the name, and shows '
              '**Pending** in the list. When the internet is back the scans '
              'are sent by themselves, or tap **Send now**. The server checks '
              'them the same as a live scan; any it refuses are listed under '
              '**See why**, so you can scan that student again. Scans must be '
              'sent within 3 days.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.slideshow_outlined,
          title: 'A short tour of the app',
          text:
              'The first time the app opens, four quick slides now show what '
              'it does: your QR code, being scanned in class, and your '
              'attendance. Swipe through, or tap **Skip**. Already using the '
              'app? See it any time from **Settings → App tour**.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.format_list_bulleted_rounded,
          title: 'A shorter Attendance List',
          text:
              'Only the five newest scans sit under the camera now, so the '
              'camera stays in view however many you scan. **View all** opens '
              'the whole list, starting on the subject you are scanning, with '
              'a chip for each subject and the search box.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.videocam_off_rounded,
          title: 'Turn the camera off between classes',
          text:
              'A **Stop camera** button now sits under the scanner, beside '
              '**Flashlight**. It switches the camera off without losing the '
              'subject you picked, and lets the screen sleep again, which '
              'saves the battery while nobody is being scanned. Tap **Turn on '
              'camera** when the next student is ready; picking a subject '
              'turns it back on too.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.cloud_off_rounded,
          title: 'Your QR code opens without internet',
          text:
              'Every QR code you make is now kept on your phone. With no '
              'internet, type your student number as usual: the app shows the '
              'QR code saved on this phone, with the day it was made, and you '
              'can still tap **Generate QR Code** and **Download QR Code**. It '
              'scans the same. A student number never looked up on this phone '
              'still needs the internet once.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.wifi_off_rounded,
          title: 'Clear messages when you are offline',
          text:
              'When the phone loses its connection, a black bar drops from '
              'the top: **You\'re offline**, and **Back online** when it '
              'returns. A look-up or sign-in that cannot get through now says '
              '**No internet connection** and what to check, instead of a '
              'technical error.',
          link: false,
        ),
      ],
    ),
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
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.home_rounded,
          title: 'A new home for students',
          text:
              'The student home now greets you by the time of day, puts **My '
              'QR Code** in a big card with a code beside it, and shows the '
              'three steps — **Save QR**, **Get scanned**, **See days** — '
              'under **My Attendance**. Everything slides into place when the '
              'app opens.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.switch_account_outlined,
          title: 'A clearer student-or-instructor question',
          text:
              '**Who is using this phone?** now shows what is behind each '
              'answer, and the card you pick lights up with a tick before the '
              'app moves on.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.fingerprint_rounded,
          title: 'The fingerprint lock, redesigned',
          text:
              'Your name sits at the top, so you know whose scanner it is. '
              'While the phone asks for your finger, a light runs over the '
              'fingerprint and rings go out from it; if the prompt is closed '
              'without unlocking, it shakes and turns red for a moment.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.notifications_active_outlined,
          title: 'Scan messages no longer stop the line',
          text:
              'When the scanner turns a code away — **Invalid QR Code**, '
              '**Not Enrolled**, **Student Photo Required** — the reason now '
              'drops out of the top of the screen in a black bar and goes '
              'away by itself, instead of a box you had to tap **OK** on. The '
              'next student can be scanned while it shows; tap it to put it '
              'away sooner.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.notifications_none_rounded,
          title: 'Messages at the top of the screen',
          text:
              '**QR code saved and ready to share**, and any problem saving '
              'it, now drop out of the top of the screen and go away by '
              'themselves.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.verified_rounded,
          title: 'A brighter welcome',
          text:
              'After you sign in, your photo — or your initials — appears in '
              'a ring that closes round it, a check lands on its corner with '
              'a burst of light, and a bar fills while your subjects load.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.logout_rounded,
          title: 'Sign out from Settings',
          text:
              '**Settings** now shows who is signed in at the top, with a '
              '**Sign out** button — as well as the one behind your picture '
              'in the scanner. It asks before it signs you out.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          icon: Icons.badge_outlined,
          title: 'A welcome for students',
          text:
              'Pick **I\'m a student** and a short opening plays first: a '
              'student card builds itself — the photo, the name, a QR code '
              'dot by dot and three days ticked off — before **My QR Code** '
              'and **My Attendance** appear.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.login_rounded,
          title: 'A new look for the sign-in',
          text:
              'The sign-in now opens with the school seal inside the '
              'scanner\'s frame, and the form rises into place under it. The '
              'scan line sweeps over the seal while your password is checked, '
              'and a wrong password shakes the form and turns the corners red '
              'for a moment.',
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
