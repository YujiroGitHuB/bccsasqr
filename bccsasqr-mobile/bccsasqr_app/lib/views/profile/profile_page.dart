import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/student_number.dart';
import '../../models/student_profile.dart';
import '../../services/photo_picker.dart';
import '../widgets/demo_mode_banner.dart';
import '../widgets/fade_scale_switcher.dart';
import '../widgets/island.dart';
import '../widgets/press_scale.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/splash_parts.dart';
import '../widgets/surface_panel.dart';
import 'photo_crop_page.dart';

/// Opens the crop for [photo]; pops with the JPEG, or null. [pickAnother]
/// fetches a replacement from the same place.
typedef PhotoCropper =
    Future<Uint8List?> Function(
      BuildContext context,
      Uint8List photo,
      Future<Uint8List?> Function() pickAnother,
    );

/// My Profile — the web's photo page (`student/StudentPhotoProfile.php`) on a
/// phone: prove the record is yours with your last name, then take or choose
/// a photo, crop it, and it is on the scanner from your next scan.
///
/// The page remembers the student (see [ProfileController]), so the second
/// visit opens straight on their face.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    this.picker = const DevicePhotoPicker(),
    this.cropper,
    this.demo = false,
  });

  final ProfileController controller;
  final PhotoPicker picker;

  /// The crop screen. Overridable for tests, which have no image decoder to
  /// spare.
  final PhotoCropper? cropper;

  /// Running on the bundled sample records — see [DemoModeBanner].
  final bool demo;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const double _maxContentWidth = 520;

  ProfileController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // A photo uploaded in the browser since, or a name an admin fixed.
    unawaited(_controller.refresh());
  }

  static Future<Uint8List?> _defaultCropper(
    BuildContext context,
    Uint8List photo,
    Future<Uint8List?> Function() pickAnother,
  ) => Navigator.of(context).push<Uint8List>(
    PageRouteBuilder(
      pageBuilder: (context, _, _) =>
          PhotoCropPage(photo: photo, pickAnother: pickAnother),
      // Up from below and fading in, like a camera opening over the page.
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
    ),
  );

  /// Take or choose, crop, save — and say how it went on the island.
  Future<void> _newPhoto(PhotoOrigin origin) async {
    if (_controller.busy != ProfileBusy.none) return;
    Future<Uint8List?> pick() => widget.picker.pick(origin);

    final Uint8List? picked;
    try {
      picked = await pick();
    } catch (_) {
      _say(ProfileStrings.pickFailed, tone: IslandTone.error);
      return;
    }
    if (picked == null || !mounted) return;

    final jpeg = await (widget.cropper ?? _defaultCropper)(
      context,
      picked,
      pick,
    );
    if (jpeg == null || !mounted) return;

    final problem = await _controller.savePhoto(jpeg);
    if (!mounted) return;
    if (problem == null) {
      Island.show(
        context,
        const IslandMessage(
          title: ProfileStrings.savedTitle,
          body: ProfileStrings.savedBody,
          tone: IslandTone.success,
          icon: Icons.face_rounded,
        ),
      );
    } else {
      _say(ProfileStrings.saveFailed, body: problem, tone: IslandTone.error);
    }
  }

  /// The camera badge on the avatar: the page's two buttons, in a sheet.
  Future<void> _choose() async {
    final origin = await showModalBottomSheet<PhotoOrigin>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('profile.sheet.camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(ProfileStrings.takePhoto),
              onTap: () => Navigator.of(context).pop(PhotoOrigin.camera),
            ),
            ListTile(
              key: const ValueKey('profile.sheet.gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(ProfileStrings.choosePhoto),
              onTap: () => Navigator.of(context).pop(PhotoOrigin.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origin != null) await _newPhoto(origin);
  }

  Future<void> _forget(StudentProfile profile) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ProfileStrings.forgetTitle),
        content: Text(ProfileStrings.forgetBody(profile.givenName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(ProfileStrings.forgetCancel),
          ),
          TextButton(
            key: const ValueKey('profile.forget.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: const Text(ProfileStrings.forgetConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _controller.forget();
    if (mounted) _say(ProfileStrings.forgotten);
  }

  void _say(String title, {String? body, IslandTone tone = IslandTone.info}) {
    if (!mounted) return;
    Island.show(context, IslandMessage(title: title, body: body, tone: tone));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final profile = _controller.profile;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                8,
                AppTheme.pagePadding,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // A page pushed over another — from My QR Code's
                          // photo warning — has a way back; the Menu's tab
                          // does not need one.
                          if (Navigator.of(context).canPop()) ...[
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              tooltip: AppStrings.homeBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ] else
                            const SizedBox(width: 4),
                          Text(
                            ProfileStrings.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FadeScaleSwitcher(
                        child: !_controller.loaded
                            ? const SizedBox.shrink(key: ValueKey('loading'))
                            : profile == null
                            ? _VerifyView(
                                key: const ValueKey('verify'),
                                controller: _controller,
                                demo: widget.demo,
                              )
                            : _ProfileView(
                                key: ValueKey(
                                  'profile.${profile.record.studentNumber}',
                                ),
                                controller: _controller,
                                profile: profile,
                                onPhoto: _newPhoto,
                                onBadge: _choose,
                                onForget: () => _forget(profile),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Step 1: who are you? ─────────────────────────────────────────────────

class _VerifyView extends StatefulWidget {
  const _VerifyView({super.key, required this.controller, required this.demo});

  final ProfileController controller;
  final bool demo;

  @override
  State<_VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends State<_VerifyView>
    with TickerProviderStateMixin {
  final TextEditingController _number = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final FocusNode _lastNameFocus = FocusNode();

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  /// A short shake of the form when the answer is no — once, then still.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _avatar = _slice(0.00, 0.45);
  late final Animation<double> _title = _slice(0.12, 0.55);
  late final Animation<double> _form = _slice(0.24, 0.72);
  late final Animation<double> _note = _slice(0.40, 0.90);

  Animation<double> _slice(double begin, double end) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  String? _shownError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _number.dispose();
    _lastName.dispose();
    _lastNameFocus.dispose();
    _intro.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onChange() {
    final error = widget.controller.error;
    if (error != null && error != _shownError) _shake.forward(from: 0);
    _shownError = error;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await widget.controller.verify(_number.text, _lastName.text);
  }

  Widget _rise(Animation<double> shown, Widget child) => AnimatedBuilder(
    animation: shown,
    child: child,
    builder: (context, child) => splashRise(shown.value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = widget.controller;
    final busy = controller.isVerifying;
    final error = controller.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _rise(_avatar, const Center(child: ProfileAvatar(size: 112))),
        const SizedBox(height: 18),
        _rise(
          _title,
          Column(
            children: [
              Text(
                ProfileStrings.verifyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ProfileStrings.verifyBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        DemoModeBanner(active: widget.demo),
        const SizedBox(height: 20),
        _rise(
          _form,
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                math.sin(_shake.value * math.pi * 5) * 8 * (1 - _shake.value),
                0,
              ),
              child: child,
            ),
            child: SurfacePanel(
              topAccent: true,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label(AppStrings.studentNumberLabel),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('profile.number'),
                    controller: _number,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: const [StudentNumberInputFormatter()],
                    onChanged: (_) => controller.clearError(),
                    onSubmitted: (_) => _lastNameFocus.requestFocus(),
                    decoration: const InputDecoration(
                      hintText: ProfileStrings.numberHint,
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Label(ProfileStrings.lastNameLabel),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('profile.lastName'),
                    controller: _lastName,
                    focusNode: _lastNameFocus,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.familyName],
                    onChanged: (_) => controller.clearError(),
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: ProfileStrings.lastNameHint,
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 17,
                                  color: colors.danger,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    error,
                                    key: const ValueKey('profile.error'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: colors.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('profile.verify'),
                    onPressed: busy ? null : _submit,
                    icon: busy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colors.textMuted,
                            ),
                          )
                        : const Icon(Icons.verified_user_outlined, size: 20),
                    label: Text(
                      busy
                          ? ProfileStrings.verifyingAction
                          : ProfileStrings.verifyAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _rise(
          _note,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: colors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ProfileStrings.verifyNote,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: context.colors.textPrimary,
    ),
  );
}

// ── Step 2: your photo ───────────────────────────────────────────────────

class _ProfileView extends StatefulWidget {
  const _ProfileView({
    super.key,
    required this.controller,
    required this.profile,
    required this.onPhoto,
    required this.onBadge,
    required this.onForget,
  });

  final ProfileController controller;
  final StudentProfile profile;
  final ValueChanged<PhotoOrigin> onPhoto;
  final VoidCallback onBadge;
  final VoidCallback onForget;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final Animation<double> _card = _slice(0.00, 0.45);
  late final Animation<double> _badge = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.30, 0.62, curve: Curves.easeOutBack),
  );
  late final Animation<double> _actions = _slice(0.20, 0.62);
  late final Animation<double> _tipsHeading = _slice(0.34, 0.72);
  late final List<Animation<double>> _tips = [
    for (var i = 0; i < ProfileStrings.tips.length; i++)
      _slice(0.42 + i * 0.07, 0.78 + i * 0.05),
  ];
  late final Animation<double> _forget = _slice(0.62, 1.00);

  Animation<double> _slice(double begin, double end) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _rise(Animation<double> shown, Widget child) => AnimatedBuilder(
    animation: shown,
    child: child,
    builder: (context, child) => splashRise(shown.value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = widget.controller;
    final profile = widget.profile;
    final record = profile.record;
    final saving = controller.isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rise(
          _card,
          SurfacePanel(
            topAccent: true,
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 152,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(
                        key: const ValueKey('profile.avatar'),
                        size: 152,
                        name: record.fullName,
                        photo: controller.pendingPhoto ?? profile.photo,
                        photoUrl: profile.photoUrl,
                        busy: saving,
                      ),
                      Positioned(
                        right: 2,
                        bottom: 4,
                        child: AnimatedBuilder(
                          animation: _badge,
                          builder: (context, child) => Transform.scale(
                            scale: _badge.value,
                            child: child,
                          ),
                          child: _CameraBadge(
                            onPressed: saving ? null : widget.onBadge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  record.fullName,
                  key: const ValueKey('profile.name'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      icon: Icons.badge_outlined,
                      label: record.studentNumber.value,
                    ),
                    _Chip(
                      icon: Icons.school_outlined,
                      label: [record.course, record.section]
                          .where((s) => s.trim().isNotEmpty)
                          .join(' · ')
                          .toUpperCase(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PhotoStatus(profile: profile, saving: saving),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _rise(
          _actions,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const ValueKey('profile.camera'),
                onPressed: saving
                    ? null
                    : () => widget.onPhoto(PhotoOrigin.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text(ProfileStrings.takePhoto),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('profile.gallery'),
                onPressed: saving
                    ? null
                    : () => widget.onPhoto(PhotoOrigin.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(ProfileStrings.choosePhoto),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _rise(
          _tipsHeading,
          const PanelHeading(
            icon: Icons.tips_and_updates_outlined,
            label: ProfileStrings.tipsHeading,
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final (i, tip) in ProfileStrings.tips.indexed)
                _rise(
                  _tips[i],
                  _Tip(
                    icon: _tipIcons[i],
                    text: tip,
                    last: i == _tipIcons.length - 1,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _rise(
          _forget,
          Center(
            child: TextButton.icon(
              key: const ValueKey('profile.forget'),
              onPressed: saving ? null : widget.onForget,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
              ),
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              label: const Text(ProfileStrings.forget),
            ),
          ),
        ),
      ],
    );
  }

  static const List<IconData> _tipIcons = [
    Icons.face_outlined,
    Icons.light_mode_outlined,
    Icons.person_outline_rounded,
    Icons.visibility_outlined,
  ];
}

/// The accent disc at the avatar's corner: change the photo.
class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      scale: 0.9,
      child: Material(
        key: const ValueKey('profile.badge'),
        color: onPressed == null ? colors.surfaceRaised : colors.accent,
        shape: CircleBorder(side: BorderSide(color: colors.surface, width: 3)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Tooltip(
            message: ProfileStrings.changePhoto,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.photo_camera_rounded,
                size: 21,
                color: onPressed == null ? colors.textMuted : colors.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// On the scanner, required, or not yet — the state of the photo, in the
/// state colours: green and amber only when that is what they mean.
class _PhotoStatus extends StatelessWidget {
  const _PhotoStatus({required this.profile, required this.saving});

  final StudentProfile profile;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, Color tint, String title, String body) = saving
        ? (
            Icons.cloud_upload_outlined,
            colors.accent,
            ProfileStrings.saving,
            ProfileStrings.savingBody,
          )
        : profile.hasPhoto
        ? (
            Icons.check_circle_rounded,
            colors.success,
            ProfileStrings.statusOnFile,
            ProfileStrings.statusOnFileBody,
          )
        : profile.photoRequired
        ? (
            Icons.warning_amber_rounded,
            colors.warning,
            ProfileStrings.statusRequired,
            ProfileStrings.statusRequiredBody,
          )
        : (
            Icons.add_a_photo_outlined,
            colors.accent,
            ProfileStrings.statusNone,
            ProfileStrings.statusNoneBody,
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Container(
        key: ValueKey(title),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: tint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: const ValueKey('profile.status'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
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
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text, required this.last});

  final IconData icon;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentWash(0.10),
              ),
              child: Icon(icon, size: 17, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13.5, color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
