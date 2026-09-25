import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../models/qr_payload.dart';

/// The card a student saves — the same picture the web page downloads.
///
/// This is a port of `paintCard()` in `QRgenerator/js/scriptv2.js`, measure
/// for measure: the same margins, the same accent rule, logo, title, code,
/// divider and label/value rows, at the same coordinates. Text positions are
/// canvas BASELINES there, so they are baselines here too.
///
/// If the web card changes, change this with it — a student who saves from
/// both should not be able to tell which one they used.
///
/// The card has a fixed size (306 × 550 for the web's 250 px code). Wrap it in
/// a `FittedBox` to show it on a narrow screen; the export captures it at its
/// own size either way.
class QrCard extends StatelessWidget {
  const QrCard({super.key, required this.payload});

  final QrPayload payload;

  // ── scriptv2.js constants ───────────────────────────────────────────
  static const double margin = 28;
  static const double logoHeight = 58;
  static const double rowHeight = 22;

  static const String title = 'BCC Student QR';

  /// INK and INK_DIM. The background is not here: it is the QR's own
  /// background from the spec, so there is no seam around the code.
  static const Color ink = Color(0xFFE2E8F0);
  static const Color inkDim = Color(0xFF8B9BB0);

  // ── geometry, exactly as paintCard() computes it ────────────────────
  double get _qrSize => payload.spec.size;
  double get width => _qrSize + margin * 2;
  static const double _titleY = margin + (logoHeight + 24) + 14;
  static const double _qrY = _titleY + 18;
  double get _dividerY => _qrY + _qrSize + 22;
  double get _detailsY => _dividerY + 26;
  double get height =>
      _detailsY + payload.details.length * rowHeight + margin - 6;

  @override
  Widget build(BuildContext context) {
    final spec = payload.spec;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CardPainter(
                background: spec.background,
                titleY: _titleY,
                dividerY: _dividerY,
                detailsY: _detailsY,
                details: payload.details,
              ),
            ),
          ),
          Positioned(
            top: margin,
            left: 0,
            right: 0,
            height: logoHeight,
            child: Image.asset(AppAssets.bccLogo, fit: BoxFit.contain),
          ),
          Positioned(
            left: margin,
            top: _qrY,
            width: _qrSize,
            height: _qrSize,
            child: QrImageView(
              data: payload.encode(),
              version: QrVersions.auto,
              size: _qrSize,
              // No padding: like qrcodejs, the code runs to its edge and the
              // card's margin is the quiet zone.
              padding: EdgeInsets.zero,
              gapless: true,
              backgroundColor: spec.background,
              errorCorrectionLevel: _level(spec.errorCorrection),
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: spec.foreground,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: spec.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _level(String level) => switch (level) {
    'L' => QrErrorCorrectLevel.L,
    'Q' => QrErrorCorrectLevel.Q,
    'H' => QrErrorCorrectLevel.H,
    _ => QrErrorCorrectLevel.M,
  };
}

/// Everything on the card that is not the logo or the code.
class _CardPainter extends CustomPainter {
  _CardPainter({
    required this.background,
    required this.titleY,
    required this.dividerY,
    required this.detailsY,
    required this.details,
  });

  final Color background;
  final double titleY;
  final double dividerY;
  final double detailsY;
  final List<QrCardRow> details;

  static const double _margin = QrCard.margin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    // The accent rule along the top — the same as the page's hero.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 4),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 4)),
    );

    _text(
      canvas,
      QrCard.title,
      const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: QrCard.ink,
      ),
      baseline: titleY,
      centerIn: size.width,
    );

    canvas.drawLine(
      Offset(_margin, dividerY + .5),
      Offset(size.width - _margin, dividerY + .5),
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..strokeWidth = 1,
    );

    // Label left, value right — it reads across even when the names are of
    // different lengths.
    for (var i = 0; i < details.length; i++) {
      final y = detailsY + i * QrCard.rowHeight;
      final label = _text(
        canvas,
        details[i].label,
        const TextStyle(fontSize: 13, color: QrCard.inkDim),
        baseline: y,
        left: _margin,
      );
      final value = details[i].value.isEmpty ? '—' : details[i].value;
      _text(
        canvas,
        value,
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: QrCard.ink,
        ),
        baseline: y,
        right: size.width - _margin,
        // The web lets a very long name run over its label; stop short of it.
        maxWidth: size.width - _margin * 2 - label - 10,
      );
    }
  }

  /// Draws [text] with its alphabetic baseline at [baseline], the way a
  /// canvas `fillText` does. Returns the width it took.
  double _text(
    Canvas canvas,
    String text,
    TextStyle style, {
    required double baseline,
    double? left,
    double? right,
    double? centerIn,
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final top =
        baseline -
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final x = centerIn != null
        ? (centerIn - painter.width) / 2
        : right != null
        ? right - painter.width
        : left!;

    painter.paint(canvas, Offset(x, top));
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  bool shouldRepaint(_CardPainter old) =>
      old.background != background ||
      old.titleY != titleY ||
      old.dividerY != dividerY ||
      old.detailsY != detailsY ||
      old.details != details;
}
