import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/qr_generator_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/terms_document.dart';
import '../services/qr_export_service.dart';
import '../services/student_repository.dart';
import 'widgets/app_footer.dart';
import 'widgets/app_header_card.dart';
import 'widgets/demo_mode_banner.dart';
import 'widgets/details_panel.dart';
import 'widgets/qr_preview_panel.dart';

/// The single screen of the app.
///
/// It owns the controller's lifecycle and translates user intent into
/// controller calls — it holds no business rules of its own.
class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({
    super.key,
    required this.repository,
    required this.exportService,
  });

  final StudentRepository repository;
  final QrExportService exportService;

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  /// Below this width the two panels stack instead of sitting side by side.
  static const double _twoColumnBreakpoint = 760;
  static const double _maxContentWidth = 1040;

  late final QrGeneratorController _controller = QrGeneratorController(
    repository: widget.repository,
  );
  final TextEditingController _studentNumberField = TextEditingController();
  final GlobalKey _qrBoundaryKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    _studentNumberField.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Could not open $url');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppColors.danger.withValues(alpha: 0.18)
              : null,
        ),
      );
  }

  /// One button drives two intents: generate, then download.
  Future<void> _handlePrimaryAction() async {
    FocusScope.of(context).unfocus();

    if (!_controller.hasQrCode) {
      await _controller.generate();
      return;
    }

    _controller.setExporting(true);
    try {
      await widget.exportService.export(
        boundaryKey: _qrBoundaryKey,
        fileStem: _controller.record!.fileStem,
        shareText:
            'BCC SASQR attendance code for ${_controller.record!.fullName}',
      );
      _showMessage(AppStrings.downloadSuccess);
    } on QrExportException catch (e) {
      _showMessage(e.message, isError: true);
    } catch (_) {
      _showMessage(AppStrings.downloadFailure, isError: true);
    } finally {
      if (mounted) _controller.setExporting(false);
    }
  }

  /// Shows the terms the SERVER is currently serving, then records the
  /// acceptance if the student agrees.
  ///
  /// The text is fetched rather than bundled, and "I Agree" stays disabled
  /// until it has arrived — agreeing to a spinner is not consent.
  Future<void> _showTerms() async {
    final future = _controller.loadTerms();

    // FutureBuilder subscribes a frame later. Without a listener attached now,
    // a request that fails immediately (airplane mode) is reported as an
    // unhandled async error before the dialog is even on screen.
    unawaited(future.then((_) {}, onError: (_) {}));

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => FutureBuilder<TermsDocument>(
        future: future,
        builder: (context, snapshot) {
          final loaded = snapshot.connectionState == ConnectionState.done;
          final failed = snapshot.hasError;
          final error = snapshot.error;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(AppStrings.termsTitle),
            content: SizedBox(
              width: 420,
              child: !loaded
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        failed
                            ? (error is StudentLookupException
                                  ? error.message
                                  : AppStrings.termsLoadFailed)
                            : snapshot.data!.text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: failed
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(AppStrings.termsClose),
              ),
              FilledButton(
                onPressed: loaded && !failed
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text(AppStrings.termsAccept),
              ),
            ],
          );
        },
      ),
    );

    if (accepted == true) _controller.setTermsAccepted(true);
  }

  void _handleReset() {
    _studentNumberField.clear();
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoColumnBreakpoint;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding,
                vertical: 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppHeaderCard(),
                        // Renders nothing when a backend was supplied.
                        DemoModeBanner(
                          active:
                              widget.repository is InMemoryStudentRepository,
                        ),
                        const SizedBox(height: 16),
                        if (wide)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _details()),
                                const SizedBox(width: 16),
                                Expanded(child: _preview(fill: true)),
                              ],
                            ),
                          )
                        else ...[
                          _details(),
                          const SizedBox(height: 16),
                          _preview(),
                        ],
                        const SizedBox(height: 26),
                        AppFooter(
                          onOpenDeveloper: () =>
                              _openUrl(AppStrings.developerUrl),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _details() => DetailsPanel(
    controller: _controller,
    textController: _studentNumberField,
    onOpenTerms: _showTerms,
    onPrimaryAction: _handlePrimaryAction,
  );

  Widget _preview({bool fill = false}) => QrPreviewPanel(
    controller: _controller,
    boundaryKey: _qrBoundaryKey,
    onReset: _handleReset,
    fill: fill,
  );
}
