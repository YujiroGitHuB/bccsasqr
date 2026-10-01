import 'package:flutter/material.dart';

/// The parts of the app the changelog talks about. Nothing else is announced
/// in the app: the web system's own changes are in its What's New.
enum WhatsNewArea { qr, tracker, profile, checkIn, scanner, links }

/// The half of the app a change was made to, when it was only one: the
/// student's Home changed on 2026-10-01 while the instructor's My QR Code
/// and Attendance did not, though both sides have those parts.
enum WhatsNewSide { student, instructor }

/// The web changelog's three item types (`includes/whats_new.php`).
enum WhatsNewKind {
  /// Something that was not there before.
  added,

  /// Something that was there and now works better.
  improved,

  /// Something that was broken.
  fixed,
}

/// One change, in words for the student or instructor holding the phone.
@immutable
class WhatsNewItem {
  const WhatsNewItem({
    required this.kind,
    required this.area,
    required this.icon,
    required this.title,
    required this.text,
    this.link = true,
    this.side,
  });

  final WhatsNewKind kind;
  final WhatsNewArea area;
  final IconData icon;
  final String title;

  /// Plain text; a phrase wrapped in `**` is shown bold — the button names
  /// the reader should look for, as the web entries do with `<strong>`.
  final String text;

  /// Whether the item gets an "Open …" button to the part it describes.
  /// A fix with nothing to go and look at leaves it off, as on the web.
  final bool link;

  /// Only one side's phones were changed. Null: both, wherever [area] is.
  final WhatsNewSide? side;

  /// Whether a reader whose phone has [areas] should see this: it is about
  /// a part they have and, when [side] says so, theirs is that side — a
  /// student's phone is the one with My Profile, an instructor's the one
  /// with the scanner.
  bool isFor(Set<WhatsNewArea> areas) =>
      areas.contains(area) &&
      switch (side) {
        null => true,
        WhatsNewSide.student => areas.contains(WhatsNewArea.profile),
        WhatsNewSide.instructor => areas.contains(WhatsNewArea.scanner),
      };
}

/// Everything announced on one day.
@immutable
class WhatsNewRelease {
  const WhatsNewRelease({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.items,
  });

  /// The release date, `2026-09-27` — the web's ids are dates too.
  final String id;

  /// Sits in the release's tile, as the web's timeline node does.
  final IconData icon;
  final String title;
  final String summary;
  final List<WhatsNewItem> items;

  DateTime get date => DateTime.parse(id);
}
