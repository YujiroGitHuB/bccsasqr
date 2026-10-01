import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/constants/whats_new_log.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/whats_new.dart';
import 'widgets/surface_panel.dart';

/// What changed in My QR Code, My Attendance, the scanner and the links,
/// newest first — the app's copy of the web's What's New timeline.
class WhatsNewPage extends StatefulWidget {
  const WhatsNewPage({
    super.key,
    this.releases = WhatsNewLog.releases,
    this.areas = const {...WhatsNewArea.values},
    this.onShown,
    this.onOpen,
  });

  final List<WhatsNewRelease> releases;

  /// The parts of the app this phone has. A student's has no scanner and no
  /// links, so their items and their filters are left out.
  final Set<WhatsNewArea> areas;

  /// Told once the page is on screen: opening it is reading it, so this is
  /// what clears the card and the dot on the home screen.
  final VoidCallback? onShown;

  /// Opens the part of the app an item is about. Left out when the page is
  /// reached from Settings, which the scanner can have open under it —
  /// opening the scanner from there would stack a second one.
  final ValueChanged<WhatsNewArea>? onOpen;

  @override
  State<WhatsNewPage> createState() => _WhatsNewPageState();
}

/// The filter along the top: everything, or one part of the app.
enum _Filter {
  all(WhatsNewStrings.filterAll, null),
  qr(WhatsNewStrings.filterQr, WhatsNewArea.qr),
  tracker(WhatsNewStrings.filterTracker, WhatsNewArea.tracker),
  profile(WhatsNewStrings.filterProfile, WhatsNewArea.profile),
  scanner(WhatsNewStrings.filterScanner, WhatsNewArea.scanner),
  links(WhatsNewStrings.filterLinks, WhatsNewArea.links);

  const _Filter(this.label, this.area);

  final String label;
  final WhatsNewArea? area;

  bool shows(WhatsNewItem item) => area == null || item.area == area;
}

class _WhatsNewPageState extends State<WhatsNewPage> {
  static const double _maxContentWidth = 560;

  _Filter _filter = _Filter.all;

  bool _shows(WhatsNewItem item) =>
      widget.areas.contains(item.area) && _filter.shows(item);

  @override
  void initState() {
    super.initState();
    // After the first frame: the home screen under this page rebuilds when
    // the mark changes, and it may not do that in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The newest release this phone has anything in: on a student's, past
    // one that is only about the instructor's side.
    final latest = widget.releases
        .where((r) => r.items.any((item) => widget.areas.contains(item.area)))
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
            vertical: 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: AppStrings.homeBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        WhatsNewStrings.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                    child: Text(
                      widget.areas.contains(WhatsNewArea.scanner)
                          ? WhatsNewStrings.intro
                          : WhatsNewStrings.introStudent,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  SegmentedButton<_Filter>(
                    segments: [
                      for (final f in _Filter.values)
                        if (f.area == null || widget.areas.contains(f.area))
                          ButtonSegment(
                            value: f,
                            label: Text(
                              f.label,
                              key: ValueKey('whatsNew.filter.${f.name}'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (picked) =>
                        setState(() => _filter = picked.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: colors.surfaceSunken,
                      foregroundColor: colors.textSecondary,
                      selectedBackgroundColor: colors.accentWash(0.14),
                      selectedForegroundColor: colors.accent,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final release in widget.releases)
                    if (release.items.any(_shows))
                      _Release(
                        release: release,
                        latest: identical(release, latest),
                        items: release.items.where(_shows).toList(),
                        onOpen: widget.onOpen,
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A date's heading, then its items.
class _Release extends StatelessWidget {
  const _Release({
    required this.release,
    required this.latest,
    required this.items,
    required this.onOpen,
  });

  final WhatsNewRelease release;
  final bool latest;
  final List<WhatsNewItem> items;
  final ValueChanged<WhatsNewArea>? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only the newest release gets the accent tile, as on the web:
              // everything below it is history.
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  gradient: latest ? AppPalette.brandMark : null,
                  color: latest ? null : colors.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: latest ? null : Border.all(color: colors.border),
                ),
                // The brand fill is the same cyan in both themes, so the ink
                // on it is too: the dark set's, which reads on cyan.
                child: Icon(
                  release.icon,
                  size: 20,
                  color: latest
                      ? AppPalette.dark.onAccent
                      : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateLabel.date(release.date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: colors.textMuted,
                          ),
                        ),
                        if (latest) ...[
                          const SizedBox(width: 8),
                          _Chip(
                            label: WhatsNewStrings.latest,
                            color: colors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release.summary,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in items) ...[
            _Item(item: item, onOpen: onOpen),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.onOpen});

  final WhatsNewItem item;
  final ValueChanged<WhatsNewArea>? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final open = onOpen;

    final (String kindLabel, Color kindColor) = switch (item.kind) {
      WhatsNewKind.added => (WhatsNewStrings.kindAdded, colors.accent),
      WhatsNewKind.improved => (WhatsNewStrings.kindImproved, colors.violet),
      WhatsNewKind.fixed => (WhatsNewStrings.kindFixed, colors.success),
    };
    final (String areaLabel, String openLabel) = switch (item.area) {
      WhatsNewArea.qr => (WhatsNewStrings.areaQr, WhatsNewStrings.openQr),
      WhatsNewArea.tracker => (
        WhatsNewStrings.areaTracker,
        WhatsNewStrings.openTracker,
      ),
      WhatsNewArea.profile => (
        WhatsNewStrings.areaProfile,
        WhatsNewStrings.openProfile,
      ),
      WhatsNewArea.scanner => (
        WhatsNewStrings.areaScanner,
        WhatsNewStrings.openScanner,
      ),
      WhatsNewArea.links => (
        WhatsNewStrings.areaLinks,
        WhatsNewStrings.openLinks,
      ),
    };

    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Chip(label: kindLabel, color: kindColor),
                    _Chip(label: areaLabel, color: colors.textSecondary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: _spans(
                      item.text,
                      TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
                if (item.link && open != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => open(item.area),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(openLabel),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                      backgroundColor: colors.accentWash(0.10),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: colors.accentWash(0.24)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `**Sign in**` → bold. Every other `**` toggles, so an odd piece is one
  /// that was wrapped.
  static List<TextSpan> _spans(String text, TextStyle bold) {
    final pieces = text.split('**');
    return [
      for (var i = 0; i < pieces.length; i++)
        if (pieces[i].isNotEmpty)
          TextSpan(text: pieces[i], style: i.isOdd ? bold : null),
    ];
  }
}

/// A small uppercase pill — the web's `.wn-tag`.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
