/// Something the server wants the student to know about their record that
/// does not stop them getting a QR, but will trip them up later.
///
/// Today the only one is `photo_missing`: with the photo requirement on, a
/// student with no photo can generate a QR here and then be refused at the
/// scanner. Saying so now is the difference between a two-minute fix at home
/// and an argument at the classroom door.
///
/// The app renders whatever the server sends — the wording and the link both
/// come from `api/v1`, so a new warning needs no new release.
class RecordWarning {
  const RecordWarning({
    required this.code,
    required this.message,
    this.actionLabel,
    this.actionUrl,
  });

  final String code;

  /// Safe to show to a student as it is.
  final String message;

  /// The button to offer, when there is somewhere to fix the problem. Both are
  /// set or neither is.
  final String? actionLabel;
  final String? actionUrl;

  bool get hasAction => actionLabel != null && actionUrl != null;

  /// Reads the API's `warnings` array.
  ///
  /// Lenient on purpose: a warning is advice, so a malformed one is dropped
  /// rather than failing the lookup and costing the student their QR.
  static List<RecordWarning> listFrom(Object? raw) {
    if (raw is! List) return const [];

    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) ?_fromJson(item),
    ];
  }

  static RecordWarning? _fromJson(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is! String || message.trim().isEmpty) return null;

    String? label;
    String? url;
    final action = json['action'];
    if (action is Map<String, dynamic>) {
      final l = action['label'];
      final u = action['url'];
      if (l is String && l.trim().isNotEmpty && u is String && _isWebLink(u)) {
        label = l;
        url = u;
      }
    }

    return RecordWarning(
      code: json['code'] as String? ?? 'unknown',
      message: message,
      actionLabel: label,
      actionUrl: url,
    );
  }

  /// Only web links: the URL is handed to the system browser, and nothing the
  /// server should ever send needs another scheme.
  static bool _isWebLink(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.isScheme('https') || uri.isScheme('http')) &&
        uri.host.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (hasAction) 'action': {'label': actionLabel, 'url': actionUrl},
  };

  @override
  bool operator ==(Object other) =>
      other is RecordWarning &&
      other.code == code &&
      other.message == message &&
      other.actionLabel == actionLabel &&
      other.actionUrl == actionUrl;

  @override
  int get hashCode => Object.hash(code, message, actionLabel, actionUrl);
}
