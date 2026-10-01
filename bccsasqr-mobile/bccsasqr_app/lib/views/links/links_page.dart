import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/links_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_link.dart';
import '../../services/link_repository.dart';
import '../../services/qr_export_service.dart';
import '../widgets/app_header_card.dart';
import '../widgets/demo_mode_banner.dart';
import '../widgets/island.dart';
import '../widgets/splash_parts.dart';
import '../widgets/surface_panel.dart';
import 'link_card.dart';
import 'link_qr_page.dart';
import 'link_time_sheet.dart';

/// Hands a line of text to the phone's share sheet.
Future<void> deviceShareText(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

/// Opens an address in the phone's browser.
Future<void> deviceOpenUrl(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

/// The instructor's attendance links — the web's Attendance Links page on a
/// phone. The same links, read from and changed on the same server, so a
/// change made here shows on the web at once and the other way round.
class LinksPage extends StatefulWidget {
  const LinksPage({
    super.key,
    required this.repository,
    required this.exportService,
    this.controller,
    this.onSignedOut,
    this.keepAwake,
    this.shareText = deviceShareText,
    this.openUrl = deviceOpenUrl,
    this.clock,
  });

  final LinkRepository repository;

  /// Saves the QR plate as a picture and shares it.
  final QrExportService exportService;

  /// The list, when it was made — and asked for — before the page: see
  /// LinksIntro, whose splash covers the wait. Kept by whoever made it. The
  /// page makes and loads its own when left out.
  final LinksController? controller;

  /// The sign-in was refused: see [LinksController.onSignedOut].
  final VoidCallback? onSignedOut;

  /// Holds the screen on while a QR code is up.
  final Future<void> Function(bool on)? keepAwake;

  final Future<void> Function(String text) shareText;
  final Future<void> Function(Uri url) openUrl;

  /// The countdowns' clock; tests step it.
  final DateTime Function()? clock;

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  static const List<HeaderChip> _chips = [
    (icon: Icons.sync_rounded, label: LinksStrings.chipSameAsWeb),
    (icon: Icons.qr_code_2_rounded, label: LinksStrings.chipQr),
  ];

  late final LinksController _controller =
      widget.controller ??
      LinksController(
        repository: widget.repository,
        onSignedOut: widget.onSignedOut,
        clock: widget.clock,
      );
  final TextEditingController _search = TextEditingController();
  late final StreamSubscription<LinkNotice> _notices;
  late final AppLifecycleListener _lifecycle;

  /// The cards rise in one after another the first time the list arrives.
  /// Made in initState, not lazily: a controller first touched in dispose
  /// would look for its ticker in a tree already coming down.
  late final AnimationController _entrance;
  bool _entered = false;

  /// Once a second, only while something is counting down and the tab is
  /// on screen.
  Timer? _ticker;
  bool _shown = true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _notices = _controller.notices.listen(_showNotice);
    _controller.addListener(_onChange);
    _lifecycle = AppLifecycleListener(
      // Back in front — maybe the next morning: yesterday's closed links
      // get their new codes, and today's classes show.
      onShow: () {
        if (_shown) unawaited(_controller.load());
      },
    );
    if (widget.controller == null) unawaited(_controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.of(context);
    // Back on this tab: the list as the server has it now, as opening the
    // web page does.
    if (shown && !_shown && _controller.hasList) {
      unawaited(_controller.load());
    }
    _shown = shown;
    // Also where a list that arrived under the splash starts the entrance.
    _onChange();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notices.cancel();
    _lifecycle.dispose();
    _controller.removeListener(_onChange);
    if (widget.controller == null) _controller.dispose();
    _entrance.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!_entered && _controller.hasList) {
      _entered = true;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (still) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    }
    _syncTicker();
  }

  void _syncTicker() {
    final want = _shown && _controller.counting;
    if (want == (_ticker != null)) return;
    _ticker?.cancel();
    _ticker = want
        ? Timer.periodic(const Duration(seconds: 1), (_) => _controller.tick())
        : null;
  }

  void _showNotice(LinkNotice notice) {
    if (!mounted) return;
    Island.show(
      context,
      IslandMessage(
        title: notice.title,
        body: notice.body,
        tone: switch (notice.tone) {
          LinkTone.success => IslandTone.success,
          LinkTone.info => IslandTone.info,
          LinkTone.warning => IslandTone.warning,
          LinkTone.error => IslandTone.error,
        },
        hold: notice.long
            ? const Duration(seconds: 6)
            : const Duration(milliseconds: 2600),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  LinkCardActions _actions(AttendanceLink link) => LinkCardActions(
    onQr: () => _openQr(link),
    onCopy: () => _copy(link),
    onShare: () => unawaited(
      widget.shareText(
        LinksStrings.shareText(
          link.subjectName,
          link.section,
          link.url,
          link.shortCode,
        ),
      ),
    ),
    onOpen: () => unawaited(widget.openUrl(Uri.parse(link.url))),
    onExpiry: () => _editExpiry(link),
    onExtend: () => _extend(link),
    onLate: () => _editLate(link),
    onRenew: () => _renew(link),
  );

  void _copy(AttendanceLink link) {
    unawaited(Clipboard.setData(ClipboardData(text: link.url)));
    Island.show(
      context,
      IslandMessage(
        title: LinksStrings.copied,
        body: LinksStrings.copiedBody(link.shortCode),
        tone: IslandTone.success,
        icon: Icons.content_copy_rounded,
      ),
    );
  }

  Future<void> _openQr(AttendanceLink link) async {
    final String? closes;
    if (_controller.isExpired(link)) {
      closes = LinksStrings.qrClosed;
    } else if (link.expiry.isSet) {
      closes = LinksStrings.qrCloses(link.expiry.short ?? link.expiry.label!);
    } else {
      closes = null;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => LinkQrPage(
          link: link,
          exportService: widget.exportService,
          keepAwake: widget.keepAwake,
          closes: closes,
          onCopy: () => _copy(link),
        ),
      ),
    );
  }

  Future<void> _editExpiry(AttendanceLink link) async {
    final time = await showExpirySheet(
      context,
      isSet: link.expiry.isSet,
      clock: widget.clock ?? DateTime.now,
    );
    if (time == null || !mounted) return;
    await _controller.setExpiry(link, time);
  }

  /// Extend — with a question when the link closed a while ago. A link that
  /// closed two hours back is most likely not the class in front of you, and
  /// extending it reopens an address already handed out. One that closed a
  /// moment ago is the real "class ran over", and gets no question.
  Future<void> _extend(AttendanceLink link) async {
    final overFor = -(_controller.expiresIn(link) ?? 0);
    if (overFor >= 7200) {
      final yes = await _confirm(
        icon: Icons.more_time_rounded,
        title: LinksStrings.extendConfirmTitle,
        body: LinksStrings.extendConfirmBody((overFor / 3600).round()),
        yes: LinksStrings.extendConfirmYes,
      );
      if (!yes || !mounted) return;
    }
    await _editExpiry(link);
  }

  Future<void> _editLate(AttendanceLink link) async {
    final time = await showLateSheet(context, isSet: link.late.on);
    if (time == null || !mounted) return;
    await _controller.setLate(link, time);
  }

  /// A new code for the next class. The new link has no expiry, so the sheet
  /// to set one opens by itself — the next step, before it is sent anywhere.
  Future<void> _renew(AttendanceLink link) async {
    final yes = await _confirm(
      icon: Icons.autorenew_rounded,
      title: LinksStrings.renewConfirmTitle,
      body: LinksStrings.renewConfirmBody,
      yes: LinksStrings.newLink,
      danger: true,
    );
    if (!yes || !mounted) return;

    final renewed = await _controller.renew(link);
    if (renewed == null || !mounted) return;
    await _editExpiry(renewed);
  }

  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String body,
    required String yes,
    bool danger = false,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          icon: Icon(icon, color: danger ? colors.danger : colors.accent),
          title: Text(title),
          content: Text(
            body,
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(LinksStrings.cancel),
            ),
            FilledButton(
              key: const ValueKey('links.confirm'),
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: danger ? colors.danger : null,
                foregroundColor: danger ? Colors.white : null,
              ),
              child: Text(yes),
            ),
          ],
        );
      },
    );
    return answer ?? false;
  }

  // ----------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The foot is left to the padding, so the list runs on under the Menu
      // button and still ends clear of it.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _controller.load,
          color: context.colors.accent,
          backgroundColor: context.colors.surfaceRaised,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final items = _items();
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  16,
                  AppTheme.pagePadding,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: items[i](context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Each row of the list, built only as it scrolls into view — an admin
  /// can have a hundred links.
  List<WidgetBuilder> _items() {
    final c = _controller;

    final head = <WidgetBuilder>[
      (_) => const AppHeaderCard(
        title: LinksStrings.title,
        tagline: LinksStrings.tagline,
        chips: _chips,
      ),
      (_) =>
          DemoModeBanner(active: widget.repository is InMemoryLinkRepository),
      (_) => const SizedBox(height: 16),
    ];

    if (c.blocked case final message?) {
      return [
        ...head,
        (_) => _Notice(
          icon: Icons.lock_outline_rounded,
          body: message,
          onRetry: c.load,
        ),
      ];
    }
    if (!c.hasList && c.error != null) {
      return [
        ...head,
        (_) => _Notice(
          icon: Icons.cloud_off_rounded,
          title: LinksStrings.loadFailed,
          body: c.error!,
          onRetry: c.load,
        ),
      ];
    }
    if (!c.hasList) {
      return [
        ...head,
        (_) => const SurfacePanel(
          child: SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (c.links.isEmpty) {
      return [
        ...head,
        (_) => _Notice(
          icon: Icons.menu_book_rounded,
          title: LinksStrings.emptyTitle,
          body: LinksStrings.emptyBody,
          onRetry: c.load,
        ),
      ];
    }

    final visible = c.visible;
    return [
      ...head,
      (_) => _Filters(controller: c, search: _search),
      (_) => const SizedBox(height: 12),
      if (visible.isEmpty)
        (_) => const _Notice(
          icon: Icons.search_off_rounded,
          title: LinksStrings.noMatchTitle,
          body: LinksStrings.noMatchBody,
        )
      else
        for (var i = 0; i < visible.length; i++)
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _rise(
              i,
              LinkCard(
                key: ValueKey(visible[i].shortCode),
                link: visible[i],
                controller: c,
                actions: _actions(visible[i]),
              ),
            ),
          ),
    ];
  }

  /// The [i]th card's share of the entrance: each starts a little after the
  /// one above it, and the first few carry the effect.
  Widget _rise(int i, Widget child) {
    final start = (i * 0.1).clamp(0.0, 0.5);
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => splashRise(curve.value, child!),
      child: child,
    );
  }
}

/// The search box, the section chips and — for an admin — whose links.
class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.search});

  final LinksController controller;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final sections = c.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PanelHeading(
              icon: Icons.link_rounded,
              label: c.admin
                  ? LinksStrings.listHeadingAdmin
                  : LinksStrings.listHeading,
            ),
            const Spacer(),
            Text(
              LinksStrings.count(c.visible.length, c.links.length),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        // A handful of links needs no search box.
        if (c.links.length > 3) ...[
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('links.search'),
            controller: search,
            onChanged: c.setSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true,
              hintText: LinksStrings.searchHint,
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ],
        if (c.admin)
          _ChipRow(
            children: [
              for (final (owner, label) in const [
                (LinkOwner.all, LinksStrings.ownerAll),
                (LinkOwner.mine, LinksStrings.ownerMine),
                (LinkOwner.others, LinksStrings.ownerOthers),
              ])
                _Chip(
                  key: ValueKey('links.owner.${owner.name}'),
                  label: label,
                  selected: c.owner == owner,
                  onSelected: () => c.setOwner(owner),
                ),
            ],
          ),
        if (sections.length > 1)
          _ChipRow(
            children: [
              _Chip(
                label: LinksStrings.allSections,
                selected: c.section == null,
                onSelected: () => c.setSection(null),
              ),
              for (final s in sections)
                _Chip(
                  key: ValueKey('links.section.$s'),
                  label: s,
                  selected: c.section == s,
                  onSelected: () => c.setSection(s),
                ),
            ],
          ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 8),
        children: children,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        backgroundColor: colors.surfaceRaised,
        selectedColor: colors.accentWash(0.16),
        side: BorderSide(color: selected ? colors.accent : colors.border),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? colors.accent : colors.textSecondary,
        ),
      ),
    );
  }
}

/// Why there are no cards: no access, no answer, nothing assigned, nothing
/// matching.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.body,
    this.title,
    this.onRetry,
  });

  final IconData icon;
  final String? title;
  final String body;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SurfacePanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          if (title case final title?) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
          if (onRetry case final retry?) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('links.retry'),
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(LinksStrings.retry),
            ),
          ],
        ],
      ),
    );
  }
}
