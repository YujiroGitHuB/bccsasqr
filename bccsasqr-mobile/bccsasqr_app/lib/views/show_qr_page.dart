import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/my_attendance_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/qr_export_service.dart';
import '../services/saved_qr_store.dart';
import 'instructor_home.dart' show shortTime;
import 'widgets/island.dart';
import 'widgets/qr_card.dart';

/// The student's QR code full screen, for the instructor's camera — the
/// same card My QR Code saves, as large as the phone allows, with the screen
/// held on while it is up.
///
/// While it is up, the app asks the records every few seconds whether a new
/// scan of today's has landed, and says so on the island: "Marked present".
/// The asking stops at the first one, when the page closes, after
/// [watchFor], or when the server asks the phone to slow down — a whole
/// class on the school Wi-Fi is one address to it.
class ShowQrPage extends StatefulWidget {
  const ShowQrPage({
    super.key,
    required this.code,
    required this.exportService,
    this.attendance,
    this.keepAwake,
    this.watchEvery = const Duration(seconds: 8),
    this.watchFor = const Duration(minutes: 3),
  });

  final SavedQr code;
  final QrExportService exportService;

  /// Whose scans to watch for. Without it the page only shows the code.
  final MyAttendanceController? attendance;

  /// Holds the screen on while the page is up, and lets it go after.
  final Future<void> Function(bool on)? keepAwake;

  final Duration watchEvery;
  final Duration watchFor;

  @override
  State<ShowQrPage> createState() => _ShowQrPageState();
}

class _ShowQrPageState extends State<ShowQrPage> {
  final GlobalKey _boundary = GlobalKey();
  Timer? _watch;
  Timer? _giveUp;
  Set<String> _seen = const {};
  bool _saving = false;

  static String _key(TodayScan s) => '${s.subject}|${s.day.timeIn}';

  @override
  void initState() {
    super.initState();
    unawaited(widget.keepAwake?.call(true));

    final attendance = widget.attendance;
    if (attendance != null && attendance.hasStudent) {
      _seen = {for (final s in attendance.today) _key(s)};
      _watch = Timer.periodic(widget.watchEvery, (_) => _check());
      _giveUp = Timer(widget.watchFor, _stopWatching);
    }
  }

  @override
  void dispose() {
    _stopWatching();
    unawaited(widget.keepAwake?.call(false));
    super.dispose();
  }

  void _stopWatching() {
    _watch?.cancel();
    _giveUp?.cancel();
    _watch = null;
    _giveUp = null;
  }

  /// One look at the records. A new scan of today's is the one just made.
  Future<void> _check() async {
    final attendance = widget.attendance;
    if (attendance == null || attendance.isLoading) return;
    await attendance.refresh();
    if (!mounted || _watch == null) return;

    if (attendance.errorCode == 'rate_limited') {
      _stopWatching();
      return;
    }

    final fresh = [
      for (final s in attendance.today)
        if (!_seen.contains(_key(s))) s,
    ];
    if (fresh.isEmpty) return;

    _stopWatching();
    final scan = fresh.first;
    unawaited(HapticFeedback.mediumImpact());
    Island.show(
      context,
      IslandMessage(
        title: ShowQrStrings.marked,
        body: ShowQrStrings.markedBody(
          scan.subject,
          shortTime(scan.day.timeIn),
          late: scan.day.late,
        ),
        tone: scan.day.late ? IslandTone.warning : IslandTone.success,
        icon: Icons.how_to_reg_rounded,
        hold: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.exportService.export(
        boundaryKey: _boundary,
        fileName: widget.code.payload.fileName,
        shareText:
            'BCC SASQR attendance code for ${widget.code.record.fullName}',
      );
      if (mounted) {
        Island.show(
          context,
          const IslandMessage(
            title: ShowQrStrings.saved,
            tone: IslandTone.success,
            icon: Icons.download_done_rounded,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Island.show(
          context,
          const IslandMessage(
            title: ShowQrStrings.saveFailed,
            tone: IslandTone.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      key: const ValueKey('showQr'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            8,
            AppTheme.pagePadding,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('showQr.close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: ShowQrStrings.close,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface,
                      side: BorderSide(color: colors.border),
                      minimumSize: const Size(46, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textPrimary,
                  ),
                  Expanded(
                    child: Text(
                      ShowQrStrings.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
              const SizedBox(height: 14),
              // As large as the screen allows, never larger than the card is
              // drawn: the export captures it at its own size either way.
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            // A shadow reads on both grounds only as black.
                            color: const Color(
                              0xFF000000,
                            ).withValues(alpha: colors.isDark ? 0.45 : 0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: RepaintBoundary(
                          key: _boundary,
                          child: QrCard(payload: widget.code.payload),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: Icons.light_mode_outlined,
                    label: ShowQrStrings.screenOn,
                  ),
                  _Pill(
                    icon: Icons.phone_android_rounded,
                    label: ShowQrStrings.offline,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ShowQrStrings.hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const ValueKey('showQr.save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.download_rounded, size: 19),
                label: const Text(ShowQrStrings.save),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
