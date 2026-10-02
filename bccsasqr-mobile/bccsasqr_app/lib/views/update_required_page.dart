import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/update_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../services/app_info.dart';
import 'widgets/splash_parts.dart';
import 'widgets/update_card.dart';

/// Instead of everything else, on a build older than the server still works
/// with — the server's `min_build` (includes/app_release.php), raised when a
/// change there breaks older builds. Before the role question and the
/// sign-in too: a build that cannot talk to the server should not half-work.
///
/// Only the way out: the download page, and Check again for a phone that
/// has just installed the update elsewhere or caught the server mid-change.
/// The pieces rise in once and the page then stands still.
class UpdateRequiredPage extends StatefulWidget {
  const UpdateRequiredPage({
    super.key,
    required this.controller,
    this.appInfo = AppInfo.load,
  });

  final UpdateController controller;
  final Future<AppInfo> Function() appInfo;

  @override
  State<UpdateRequiredPage> createState() => _UpdateRequiredPageState();
}

class _UpdateRequiredPageState extends State<UpdateRequiredPage>
    with SingleTickerProviderStateMixin {
  /// Made in initState, not lazily, like every controller a screen owns.
  late final AnimationController _intro;
  late final List<Animation<double>> _pieces;
  late final Future<AppInfo> _installed = widget.appInfo();

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pieces = [
      for (var i = 0; i < 4; i++)
        CurvedAnimation(
          parent: _intro,
          curve: Interval(
            0.1 * i,
            (0.1 * i + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
    ];
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _rise(int i, Widget child) => AnimatedBuilder(
    animation: _pieces[i],
    child: child,
    builder: (context, child) => splashRise(_pieces[i].value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final update = widget.controller;

    return Scaffold(
      key: const ValueKey('updateRequired'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: update,
                builder: (context, _) {
                  final newest = update.release?.version;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The page's one bright element.
                      _rise(
                        0,
                        Center(
                          child: Container(
                            height: 76,
                            width: 76,
                            decoration: BoxDecoration(
                              gradient: AppPalette.brandMark,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Icon(
                              Icons.system_update_rounded,
                              size: 38,
                              color: colors.onAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _rise(
                        1,
                        Column(
                          children: [
                            Text(
                              UpdateStrings.requiredTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              UpdateStrings.requiredBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _rise(
                        2,
                        FutureBuilder<AppInfo>(
                          future: _installed,
                          builder: (context, info) => Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (newest != null)
                                _Chip(
                                  icon: Icons.new_releases_outlined,
                                  text: UpdateStrings.requiredNewest(newest),
                                ),
                              if (info.data case final installed?)
                                _Chip(
                                  icon: Icons.phone_android_rounded,
                                  text: UpdateStrings.requiredInstalled(
                                    installed.label,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      _rise(
                        3,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('updateRequired.download'),
                              onPressed: () =>
                                  openDownloadPage(context, update.downloadUrl),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text(UpdateStrings.requiredDownload),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              key: const ValueKey('updateRequired.retry'),
                              onPressed: update.asking
                                  ? null
                                  : () => unawaited(update.check(force: true)),
                              icon: update.asking
                                  ? SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.textSecondary,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(UpdateStrings.requiredRetry),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
