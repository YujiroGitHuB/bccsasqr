import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// "Sign out of the scanner?" — asked by Settings → Account. True only for
/// a yes.
///
/// [pending] scans still kept on the phone are said plainly, so nobody signs
/// out thinking a class is in the records when it is not yet.
Future<bool> confirmSignOut(BuildContext context, {int pending = 0}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.logout_rounded, color: context.colors.danger),
      title: const Text(ScannerStrings.signOutConfirmTitle),
      content: Text(
        pending > 0
            ? '${ScannerStrings.signOutPendingBody(pending)}\n\n'
                  '${ScannerStrings.signOutConfirmBody}'
            : ScannerStrings.signOutConfirmBody,
        style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(ScannerStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: context.colors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text(ScannerStrings.signOut),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
