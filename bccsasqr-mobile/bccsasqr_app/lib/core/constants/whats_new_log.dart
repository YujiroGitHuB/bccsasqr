import 'package:flutter/material.dart';

import '../../models/whats_new.dart';

/// The app's What's New — only what changed in My QR Code, My Attendance, My
/// Profile, Check in, the Attendance Scanner and the attendance links. The
/// web system keeps its own, fuller changelog in
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
  static const String version = '2026-10-02.3';

  static const List<WhatsNewRelease> releases = [
    WhatsNewRelease(
      id: '2026-10-02',
      icon: Icons.event_busy_rounded,
      title: 'Your absences, offline too, and a word on updates',
      summary:
          'Attendance now counts your absences — the days your class was '
          'scanned and you were not — in each subject, and lists the days you '
          'missed in red among the days you were there. Every subject you are '
          'enrolled in shows, even one you have never been scanned in. Your '
          'attendance now stays on the phone for when there is no signal, and '
          'the app tells you when a newer version is on the download page.',
      items: [
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.cloud_off_rounded,
          title: 'Your attendance, even with no signal',
          text:
              'Home and **Attendance** now keep your attendance on the phone. '
              'With no signal — in a classroom, say — they show it as it was '
              'last updated, marked **Saved on this phone · as of** the time, '
              'instead of "Could not load", and update themselves once you are '
              'back online. **Not you?** removes it from the phone.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          icon: Icons.system_update_rounded,
          title: 'Told when there is a newer app',
          text:
              'The app now checks the download page when it opens. When a '
              'newer version is there, **Update available** shows on Home, '
              'with the size of the download — tap it to get it, or close it '
              'until the next one — and Settings names it under **Get the '
              'latest version**. Install it over this one: your QR code and '
              'settings stay.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.event_busy_rounded,
          title: 'See your absences',
          text:
              '**Attendance** now shows how many classes you missed in each '
              'subject — "12 of 14 classes attended · 2 absent" — with the '
              'days you missed in red among the days you were there. Tap '
              '**Absent** to see only those; Home counts them too. An absence '
              'is a day your class was scanned and you were not. Today\'s '
              'classes count once the day is over, so waiting in line is never '
              'an absence.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.playlist_add_check_rounded,
          title: 'Every subject you are enrolled in',
          text:
              '**Attendance** now lists every subject you are enrolled in, with '
              'its section — even one you have never been scanned in, which '
              'used to be missing from the list. A class that has not been '
              'scanned yet says so.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.instructor,
          icon: Icons.event_busy_rounded,
          title: 'The Attendance Tracker shows absences',
          text:
              'Look up a student in **Attendance** and you now see their '
              'absences in each subject, the days missed among the days '
              'present, and every subject they are enrolled in — even one they '
              'were never scanned in. The web tracker shows the same.',
        ),
      ],
    ),
    WhatsNewRelease(
      id: '2026-10-01',
      icon: Icons.grid_view_rounded,
      title: 'One Menu button, and attendance as it happens',
      summary:
          'The bottom of the screen is now only the round Menu button, on '
          'both sides of the app, and the Menu sorts its parts into named '
          'groups. Students get a new Home with their QR code on a card that '
          'turns over by itself, their own attendance with nothing to type, '
          'Check in for classes that use an attendance link — paste the '
          'shared link, or turn the camera on to scan, and confirm with your '
          'fingerprint — and a fingerprint lock. Students are now told the '
          'moment they are marked present, on any page, with no pull to '
          'refresh, and Notifications lists every change. Instructors open '
          'straight on Home, the scanner\'s splash plays when you open the '
          'Scanner, and a shared link carries its class code. A phone opening '
          'the app for the first time gets a short opening after Get started.',
      items: [
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.delete_sweep_outlined,
          title: 'Delete notifications',
          text:
              'Swipe a notification sideways to delete it — tap the note at '
              'the top of the screen to undo — or tap **Clear all** at the top '
              'of Notifications. Only the list on your phone is cleared; your '
              'attendance stays on your record.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.fixed,
          area: WhatsNewArea.checkIn,
          side: WhatsNewSide.student,
          icon: Icons.alt_route_rounded,
          title: 'Check in takes only your own section\'s class',
          text:
              '**Check in** now makes sure the class is your section\'s. A link '
              'or class code from another section of the same subject is '
              'refused, and the message says which section you are enrolled '
              'in. Irregular students check in to the class they take the '
              'subject with, as before.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.fixed,
          area: WhatsNewArea.links,
          icon: Icons.alt_route_rounded,
          title: 'Check-ins through your link stay in your section',
          text:
              'A student enrolled in the same subject in another section is '
              'now turned away from your link — by its QR or its code, in the '
              'app or on the web form — and told which section to use. The '
              'attempt shows in Attendance Integrity on the web as **Other '
              'section**.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.notifications_active_outlined,
          title: 'Told the moment you are marked present',
          text:
              'When your instructor scans your QR code, **Marked present** '
              'drops in at the top of your screen within seconds — on Home, on '
              '**Show to scanner**, anywhere in the app — and Home\'s **Marked '
              'present today** and your attendance update by themselves. No '
              'more pulling down to refresh. A late mark, a scan your '
              'instructor\'s phone sent later, and a record your instructor '
              'removed are told the same way. Prefer it quiet? Turn off '
              '**Attendance alerts** in Settings.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.notifications_none_rounded,
          title: 'Notifications: every change, in one list',
          text:
              'Tap the bell beside What\'s New on Home — or **Notifications** '
              'in the Menu — for every change to your attendance, newest '
              'first. The bell counts what you have not seen yet, and what '
              'happened while the app was closed is there the next time you '
              'open it.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          side: WhatsNewSide.student,
          icon: Icons.flip_rounded,
          title: 'Your card turns by itself',
          text:
              'The card on Home now turns over every few seconds, so your '
              'details and your QR code both show without a touch. Turn it '
              'yourself — drag, tap, or **Card** / **QR code** — and it stays '
              'where you leave it. Rather it stood still? Turn off **Turn the '
              'card by itself** in Settings.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          side: WhatsNewSide.instructor,
          icon: Icons.mark_email_read_outlined,
          title: 'Students see your scan on their own phone',
          text:
              'A student with the app now gets **Marked present** — or '
              '**Marked late** — on their phone within seconds of your scan, '
              'so the line at the door can check for themselves instead of '
              'asking. Scans kept offline tell them when they reach the '
              'records.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.checkIn,
          side: WhatsNewSide.student,
          icon: Icons.refresh_rounded,
          title: 'Check in: an opening, and pull to refresh',
          text:
              'The first time you open **Check in**, a short opening plays, '
              'as **My QR Code** and **Attendance** do. Pull the page down to '
              'refresh the class on it — its late and closing times — or to '
              'start over. **Stop** for the camera now sits beside **Scan the '
              'class QR**, no longer over the picture.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.checkIn,
          side: WhatsNewSide.student,
          icon: Icons.verified_user_outlined,
          title: 'Your fingerprint confirms each check-in',
          text:
              'On a phone with a screen lock, **Check in as …** now asks for '
              'your fingerprint, face or PIN before it sends — so nobody else '
              'who picks up your phone can check in as you. The button shows '
              'a fingerprint when it will ask.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.links,
          icon: Icons.verified_user_outlined,
          title: 'Check-ins from the app need the student\'s fingerprint',
          text:
              'When a student checks in through your link from the app, it '
              'now asks for their fingerprint, face or PIN first, on any '
              'phone with a screen lock — so a classmate holding an absent '
              'student\'s phone cannot check them in.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.profile,
          side: WhatsNewSide.student,
          icon: Icons.fingerprint_rounded,
          title: 'Lock the app with your fingerprint',
          text:
              'Turn on **Fingerprint lock** in Settings, under **Privacy** — '
              'or say yes when it is offered after you set up your phone — '
              'and the app opens only with your phone\'s fingerprint, face or '
              'screen lock. It locks again after a minute away, so nobody '
              'else who picks up your phone can show your QR code or check in '
              'as you. **Not you?** on the lock removes your profile from the '
              'phone instead.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.checkIn,
          side: WhatsNewSide.student,
          icon: Icons.content_paste_rounded,
          title: 'Paste the link your instructor shared',
          text:
              'Copy your instructor\'s message from the group chat — the '
              'whole message, the link, or just the class code — then open '
              '**Check in** and tap **Paste link or code**. The class comes '
              'up at once. Pasting into the code boxes from your keyboard '
              'works too.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.checkIn,
          side: WhatsNewSide.student,
          icon: Icons.videocam_off_rounded,
          title: 'The camera waits until you turn it on',
          text:
              '**Check in** now opens with the camera off. Tap **Scan the '
              'class QR** to turn it on, and **Stop** beside it to turn it '
              'off again — the app remembers which you chose.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.links,
          icon: Icons.share_rounded,
          title: 'The class code in the message you share',
          text:
              '**Share** on a link now adds the class code on a line of its '
              'own. Students with the app copy the whole message, the link or '
              'just the code, and tap **Paste link or code** in **Check in** '
              '— no typing.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.profile,
          side: WhatsNewSide.student,
          icon: Icons.category_outlined,
          title: 'The Menu, sorted into groups',
          text:
              'Each part of the **Menu** now sits under a name, so it is '
              'quicker to find: **IN CLASS** for **Show my QR code** and '
              '**Check in**, **MY RECORDS** for **My QR Code**, **Attendance** '
              'and **My Profile**, **GENERAL** for **Home**, What\'s New, '
              'Settings and the App tour, and **ACCOUNT** at the bottom for '
              'whose phone it is.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.profile,
          side: WhatsNewSide.student,
          icon: Icons.celebration_outlined,
          title: 'An opening after Get started',
          text:
              'On a phone opening the app for the first time, **Get started** '
              'at the end of the introduction — or **Skip** — now plays a '
              'short opening: the QR code, the scan and the attendance gather '
              'round the school seal before the app asks who is using the '
              'phone.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.scanner,
          icon: Icons.category_outlined,
          title: 'The Menu, sorted into groups',
          text:
              'Each part of the **Menu** now sits under a name, so it is '
              'quicker to find: **IN CLASS** for **Scan attendance**, '
              '**Today\'s scans** and **Links**, **STUDENTS** for **QR Code** '
              'and **Attendance**, **GENERAL** for **Home**, What\'s New, '
              '**Settings** and the App tour, and **ACCOUNT** at the bottom '
              'for your sign-in and **Sign out**.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.scanner,
          icon: Icons.celebration_outlined,
          title: 'An opening after Get started',
          text:
              'On a phone opening the app for the first time, **Get started** '
              'at the end of the introduction — or **Skip** — now plays a '
              'short opening: the QR code, the scan and the attendance gather '
              'round the school seal before the app asks who is using the '
              'phone.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          side: WhatsNewSide.student,
          icon: Icons.badge_outlined,
          title: 'Your QR code on a card you can turn',
          text:
              'On Home, your code is now on a student card: your photo, name, '
              'number and course on the front, the QR code on the back. Drag '
              'it sideways to turn it, or tap it to flip it — **Card** and '
              '**QR code** under it do the same. When it is time to be '
              'scanned, tap **Show to scanner**: the flat code reads best.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.qr,
          side: WhatsNewSide.student,
          icon: Icons.qr_code_2_rounded,
          title: 'Your QR code, right on Home',
          text:
              'Set up your phone once in **My Profile** — your student number '
              'and last name — and Home shows your QR code itself. Tap '
              '**Show to scanner** and it fills the screen, which stays on '
              'until you close it, even with no internet. **Save to gallery** '
              'is there too.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.qr,
          side: WhatsNewSide.student,
          icon: Icons.how_to_reg_rounded,
          title: 'Know when you are marked present',
          text:
              'While your code is on screen, the app checks the records every '
              'few seconds and says **Marked present** at the top of the '
              'screen as soon as your instructor\'s scan goes through. Home '
              'says it too: **Marked present today**, with the subject and '
              'time.',
          link: false,
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.tracker,
          side: WhatsNewSide.student,
          icon: Icons.event_available_rounded,
          title: 'Your attendance, with nothing to type',
          text:
              '**My Attendance** now opens on your own record: days present, '
              'subjects and the day you last attended, then each subject with '
              'its days. **All**, **On time** and **Late** narrow the days. '
              'Home shows the three numbers and your latest subjects.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.added,
          area: WhatsNewArea.checkIn,
          side: WhatsNewSide.student,
          icon: Icons.qr_code_scanner_rounded,
          title: 'Check in with the class code',
          text:
              'For classes that use an attendance link: open **Check in**, '
              'point the camera at the class QR on the screen or board — or '
              'type the six letters under it — and tap **Check in as …**. It '
              'sends the student your phone is set up for, so there is no '
              'number to type, and says if you are on time or late.',
        ),
        WhatsNewItem(
          kind: WhatsNewKind.improved,
          area: WhatsNewArea.profile,
          side: WhatsNewSide.student,
          icon: Icons.grid_view_rounded,
          title: 'One Menu button at the bottom',
          text:
              'Tap the round **Menu** button for any part: **Show my QR '
              'code**, **My QR Code**, **Attendance**, **Check in**, **My '
              'Profile**, What\'s New and Settings. On a phone you share, '
              '**Not you?** at the bottom of the Menu removes your profile '
              'from it — nothing changes on your school record.',
          link: false,
        ),
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
