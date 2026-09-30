import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_link.dart';
import '../../models/qr_payload.dart';
import '../../services/qr_export_service.dart';
import '../widgets/island.dart';

/// A link's QR code, as big as the phone allows — held up to the class, or
/// saved and posted. The web page's QR modal.
///
/// Black on white, whatever the theme: a camera measures the contrast, and
/// the QR spec expects dark modules on a light ground. Error correction H,
/// as on the web, so a code on a projector or a cracked screen still reads.
///
/// The screen stays on while it is open: nobody touches the phone while a
/// class files past it.
class LinkQrPage extends StatefulWidget {
  const LinkQrPage({
    super.key,
    required this.link,
    required this.exportService,
    required this.onCopy,
    this.keepAwake,
    this.closes,
  });

  final AttendanceLink link;
  final QrExportService exportService;
  final VoidCallback onCopy;

  /// Holds the screen on while the code is up; nothing when left out.
  final Future<void> Function(bool on)? keepAwake;

  /// "Closes 5:00 PM" under the code, when the link has an expiry.
  final String? closes;

  @override
  State<LinkQrPage> createState() => _LinkQrPageState();
}

class _LinkQrPageState extends State<LinkQrPage> {
  final GlobalKey _plate = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.keepAwake?.call(true));
  }

  @override
  void dispose() {
    unawaited(widget.keepAwake?.call(false));
    super.dispose();
  }

  Future<void> _share() async {
    final link = widget.link;
    setState(() => _sharing = true);
    try {
      await widget.exportService.export(
        boundaryKey: _plate,
        fileName: QrPayload.safeFileName(
          'attendance-qr-${link.subjectCode}-${link.section}',
        ),
        shareText: LinksStrings.shareText(
          link.subjectName,
          link.section,
          link.url,
        ),
      );
    } catch (_) {
      if (mounted) {
        Island.show(
          context,
          const IslandMessage(
            title: LinksStrings.qrShareFailed,
            tone: IslandTone.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final link = widget.link;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // As wide as the screen allows, and still leaving room for the
            // words and the buttons on a short phone.
            final side = (constraints.maxWidth - 2 * AppTheme.pagePadding - 40)
                .clamp(160.0, (constraints.maxHeight - 330).clamp(160.0, 420.0))
                .toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding,
                vertical: 8,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('linkQr.close'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: LinksStrings.close,
                        icon: const Icon(Icons.close_rounded),
                        color: colors.textSecondary,
                      ),
                      Expanded(
                        child: Text(
                          link.section,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    key: _plate,
                    child: _Plate(link: link, side: side),
                  ),
                  const SizedBox(height: 16),
                  // The icon rides in the line, so it stays beside the
                  // words when they wrap.
                  Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.phone_iphone_rounded,
                              size: 16,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                        const TextSpan(text: LinksStrings.qrHint),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  if (widget.closes case final closes?) ...[
                    const SizedBox(height: 6),
                    Text(
                      closes,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('linkQr.share'),
                            onPressed: _sharing ? null : _share,
                            icon: const Icon(Icons.ios_share_rounded, size: 20),
                            label: const Text(LinksStrings.qrShare),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('linkQr.copy'),
                            onPressed: widget.onCopy,
                            icon: const Icon(
                              Icons.content_copy_rounded,
                              size: 18,
                            ),
                            label: const Text(LinksStrings.copy),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The white card that is saved and shared: the code, and enough words
/// under it that the picture explains itself in a group chat.
class _Plate extends StatelessWidget {
  const _Plate({required this.link, required this.side});

  final AttendanceLink link;
  final double side;

  /// Always the light palette: the plate is paper, in either theme.
  static const AppPalette _paper = AppPalette.light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: _paper.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${LinksStrings.qr}, ${link.url}',
            image: true,
            child: QrImageView(
              key: const ValueKey('linkQr.code'),
              data: link.url,
              size: side,
              padding: EdgeInsets.zero,
              backgroundColor: _paper.surface,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: side,
            child: Column(
              children: [
                Text(
                  link.shortCode,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: _paper.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${link.subjectCode} · ${link.section}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _paper.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  link.subjectName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: _paper.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
