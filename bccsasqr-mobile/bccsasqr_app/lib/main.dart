import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'services/check_in_repository.dart';
import 'services/connectivity.dart';
import 'services/device_lock.dart';
import 'services/notice_store.dart';
import 'services/onboarding_store.dart';
import 'services/profile_store.dart';
import 'services/saved_qr_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
  runApp(
    // The collaborators that only a real phone can back; see their notes
    // on BccSasqrApp.
    BccSasqrApp(
      connectivity: DeviceConnectivityService(),
      savedQrStore: SharedPrefsSavedQrStore(),
      onboardingStore: SharedPrefsOnboardingStore(),
      profileStore: SharedPrefsProfileStore(),
      deviceTokenStore: SharedPrefsDeviceTokenStore(),
      noticeStore: SharedPrefsNoticeStore(),
      deviceLock: LocalAuthDeviceLock(),
      studentLockStore: const SharedPrefsLockSwitchStore.student(),
    ),
  );
}
