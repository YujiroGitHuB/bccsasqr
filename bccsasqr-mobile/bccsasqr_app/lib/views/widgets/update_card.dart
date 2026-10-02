import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'island.dart';
import 'surface_panel.dart';

/// "Update available" — under the greeting on both Homes while the download
/// page has a newer app than this one (UpdateController), until it is closed
/// for that build. A tap opens the download page; the cross closes it.
///
/// Laid out like Home's What's New card, the ink on top of the panel and the
/// close button above the ink, so a tap on the cross only closes.
class UpdateCard extends StatelessWidget {
  const UpdateCard({
    super.key,
    required this.version,
    this.megabytes,
    required this.onUpdate,
    required this.onClose,
  });

  final String version;

  /// The download's size, for a phone on mobile data.
  final int? megabytes;
  final VoidCallback onUpdate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      key: const ValueKey('update.card'),
      children: [
        MergeSemantics(
          child: Stack(
            children: [
              SurfacePanel(
                borderColor: colors.accentWash(0.35),
                padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: colors.accentWash(0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 21,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            UpdateStrings.cardTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            UpdateStrings.cardBody(version, megabytes),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: const ValueKey('update.open'),
                    onTap: onUpdate,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            key: const ValueKey('update.close'),
            onPressed: onClose,
            tooltip: UpdateStrings.cardClose,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded),
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The download page in the phone's browser — where the update is — or, when
/// it will not open, a word on the island.
Future<void> openDownloadPage(BuildContext context, String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  final opened =
      uri != null &&
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((Object _) => false);
  if (!opened && context.mounted) {
    Island.show(
      context,
      const IslandMessage(
        title: UpdateStrings.openFailed,
        tone: IslandTone.error,
      ),
    );
  }
}
