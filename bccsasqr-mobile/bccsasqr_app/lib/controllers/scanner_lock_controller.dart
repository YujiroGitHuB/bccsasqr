import '../core/constants/app_strings.dart';
import 'phone_lock_controller.dart';

export 'phone_lock_controller.dart';

/// The phone's lock in front of a saved instructor sign-in, in the
/// scanner's words.
///
/// Only ever a second door: there is nothing to unlock until an instructor
/// has signed in with their email and password, and signing out takes the
/// lock away with the sign-in. Off until the instructor turns it on — the
/// scanner offers it once, right after a sign-in.
class ScannerLockController extends PhoneLockController {
  ScannerLockController({
    required super.device,
    required super.store,
    super.clock,
  }) : super(
         reason: ScannerStrings.lockReason,
         enableReason: ScannerStrings.lockEnableReason,
         notUnlocked: ScannerStrings.lockNotUnlocked,
       );

  /// Away from the app this long, and the scanner locks again.
  static const Duration relockAfter = PhoneLockController.relockAfter;
}
