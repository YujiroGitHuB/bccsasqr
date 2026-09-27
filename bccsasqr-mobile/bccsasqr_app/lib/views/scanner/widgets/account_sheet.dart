import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import 'scanner_header.dart';

/// What the account sheet was closed with.
enum AccountAction { settings, signOut }

/// The sheet behind the avatar: who is signed in, Settings, and Sign out.
///
/// Returns what was picked, and leaves acting on it to the caller — the
/// sheet has to be off the screen before a confirmation or a new page opens
/// over it.
Future<AccountAction?> showAccountSheet(
  BuildContext context, {
  required ScannerUser user,
  required int subjectCount,
}) => showModalBottomSheet<AccountAction>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _AccountSheet(user: user, subjectCount: subjectCount),
);

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({required this.user, required this.subjectCount});

  final ScannerUser user;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(user: user, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            UserChips(user: user, subjectCount: subjectCount),
            const SizedBox(height: 18),
            Material(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => Navigator.pop(context, AccountAction.settings),
                leading: Icon(Icons.settings_outlined, color: colors.accent),
                title: Text(
                  SettingsStrings.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  ScannerStrings.settingsTileBody,
                  style: TextStyle(color: colors.textSecondary),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tonal red rather than a solid one: signing out is a normal
            // thing to do at the end of the day, not a warning.
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, AccountAction.signOut),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(ScannerStrings.signOut),
              style: FilledButton.styleFrom(
                backgroundColor: colors.danger.withValues(alpha: 0.12),
                foregroundColor: colors.danger,
                side: BorderSide(color: colors.danger.withValues(alpha: 0.35)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
