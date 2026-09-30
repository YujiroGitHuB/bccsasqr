import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/offline_scan.dart';

/// Under the camera, only while there is something to say about the
/// internet: that the scanner is offline and keeping scans, how many are
/// waiting to be sent (with **Send now**), and any the server refused once
/// they were (with **See why**). Nothing at all the rest of the time.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.controller});

  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final pending = c.pendingCount;
    final refused = c.notSaved.length;

    final strips = [
      if (c.isSyncing && pending > 0)
        _Strip(
          icon: Icons.cloud_upload_outlined,
          color: colors.accent,
          title: ScannerStrings.sendingTitle(pending),
          busy: true,
        )
      else if (pending > 0)
        _Strip(
          icon: c.isOffline
              ? Icons.cloud_off_rounded
              : Icons.cloud_upload_outlined,
          color: c.isOffline ? colors.warning : colors.accent,
          title: ScannerStrings.pendingTitle(pending),
          body: c.isOffline
              ? ScannerStrings.offlineBody
              : ScannerStrings.pendingBody,
          action: ScannerStrings.sendNow,
          onAction: c.sync,
        )
      else if (c.isOffline)
        _Strip(
          icon: Icons.cloud_off_rounded,
          color: colors.warning,
          title: ScannerStrings.offlineTitle,
          body: ScannerStrings.offlineBody,
        ),
      if (refused > 0)
        _Strip(
          icon: Icons.error_outline_rounded,
          color: colors.danger,
          title: ScannerStrings.notSavedCountTitle(refused),
          action: ScannerStrings.seeWhy,
          onAction: () => showNotSavedSheet(context, c),
        ),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: strips.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, strip) in strips.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    strip,
                  ],
                ],
              ),
            ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.color,
    required this.title,
    this.body,
    this.action,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  /// Sending right now: a spinner where the icon was, and no button.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (body case final body?) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action case final action? when !busy)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(action),
            ),
        ],
      ),
    );
  }
}

/// The kept scans the server refused, each with its reason — the same
/// reasons a live scan is refused with. Cleared when the instructor is done
/// with them.
Future<void> showNotSavedSheet(
  BuildContext context,
  ScannerController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (context) {
      final colors = context.colors;
      final scans = controller.notSaved;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                ScannerStrings.notSavedSheetTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                ScannerStrings.notSavedSheetBody,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: scans.length,
                itemBuilder: (context, i) =>
                    _NotSavedRow(scan: scans[i], divider: i > 0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton(
                onPressed: () {
                  controller.dismissNotSaved();
                  Navigator.of(context).pop();
                },
                child: const Text(ScannerStrings.notSavedClear),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _NotSavedRow extends StatelessWidget {
  const _NotSavedRow({required this.scan, required this.divider});

  final PendingScan scan;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: colors.border)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scan.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${scanDate(scan.scannedAt)} · ${scanTime(scan.scannedAt)}',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (scan.name.isNotEmpty) scan.studentNumber,
              scan.subjectName,
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            scan.rejection?.message ?? '',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
