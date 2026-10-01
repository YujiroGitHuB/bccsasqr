import 'package:flutter/material.dart';

import '../../controllers/scanner_lock_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../models/scanner_models.dart';
import '../widgets/phone_lock_screen.dart';
import 'widgets/scanner_header.dart';

export '../widgets/phone_lock_screen.dart' show showLockOffer;

/// In front of a saved sign-in when the lock is on: whose scanner it is, and
/// the phone's own prompt, asked for straight away. The camera is not started
/// until it opens. The lock screen both sides share (PhoneLockScreen), in
/// the scanner's words.
class ScannerLockScreen extends StatelessWidget {
  const ScannerLockScreen({
    super.key,
    required this.lock,
    required this.user,
    required this.onUsePassword,
  });

  final ScannerLockController lock;
  final ScannerUser? user;

  /// Signs out, for the password instead — a finger that will not read, or
  /// someone else's phone lock.
  final VoidCallback onUsePassword;

  /// How long the screen is up before the system prompt covers it.
  static const Duration promptDelay = PhoneLockScreen.promptDelay;

  @override
  Widget build(BuildContext context) {
    final user = this.user;

    return PhoneLockScreen(
      lock: lock,
      title: ScannerStrings.lockTitle,
      body: ScannerStrings.lockBody,
      owner: user == null
          ? null
          : LockOwnerChip(
              avatar: UserAvatar(user: user, size: 30),
              name: user.name,
            ),
      alternative: (
        name: 'password',
        icon: Icons.password_rounded,
        label: ScannerStrings.lockUsePassword,
        onPressed: onUsePassword,
      ),
    );
  }
}
