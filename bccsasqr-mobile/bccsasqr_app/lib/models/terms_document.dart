/// The Terms and Conditions as the server authored them.
///
/// The text is not bundled in the app on purpose. It lives in
/// `includes/terms.php` on the server, and raising `TERMS_VERSION` there is
/// what makes every student — on the web and in the app — be asked again. A
/// copy shipped inside an APK could never be raised without a release.
class TermsDocument {
  const TermsDocument({
    required this.version,
    required this.text,
    this.contact = '',
  });

  /// Matches the version recorded against an acceptance.
  final int version;

  /// Plain text. The API also returns the authored HTML, but a dialog does not
  /// need a HTML renderer for it.
  final String text;

  /// The office to contact about a wrong record.
  final String contact;

  factory TermsDocument.fromJson(Map<String, dynamic> json) => TermsDocument(
    version: (json['version'] as num?)?.toInt() ?? 1,
    text: (json['text'] as String? ?? '').trim(),
    contact: json['contact'] as String? ?? '',
  );
}
