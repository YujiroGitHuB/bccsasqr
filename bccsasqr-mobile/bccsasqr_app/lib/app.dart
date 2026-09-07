import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'services/http_student_repository.dart';
import 'services/qr_export_service.dart';
import 'services/student_repository.dart';
import 'views/qr_generator_page.dart';

/// Root widget. Composes the dependency graph in one place so the views take
/// their collaborators by constructor rather than reaching for globals.
class BccSasqrApp extends StatefulWidget {
  const BccSasqrApp({super.key, this.repository, this.exportService});

  /// Overridable for tests.
  final StudentRepository? repository;
  final QrExportService? exportService;

  @override
  State<BccSasqrApp> createState() => _BccSasqrAppState();
}

class _BccSasqrAppState extends State<BccSasqrApp> {
  /// Real backend when one was supplied at build time, bundled demo records
  /// otherwise — see [AppConfig].
  late final StudentRepository _repository =
      widget.repository ??
      (AppConfig.hasRemoteApi
          ? HttpStudentRepository()
          : InMemoryStudentRepository());
  late final QrExportService _exportService =
      widget.exportService ?? const ImageQrExportService();

  @override
  void dispose() {
    final repository = _repository;
    if (repository is HttpStudentRepository) repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: QrGeneratorPage(
        repository: _repository,
        exportService: _exportService,
      ),
    );
  }
}
