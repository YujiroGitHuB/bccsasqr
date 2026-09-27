import 'package:flutter/material.dart';

/// The three parts of the app the changelog talks about. Nothing else is
/// announced in the app: the web system's own changes are in its What's New.
enum WhatsNewArea { qr, tracker, scanner }

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
