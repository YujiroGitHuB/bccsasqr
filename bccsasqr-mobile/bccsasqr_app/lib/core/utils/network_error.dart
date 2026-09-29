import 'dart:async';

/// What to tell the person holding the phone when a request got no answer at
/// all — no Wi-Fi, no mobile data, or a server too slow to reply.
///
/// Both repositories used to show the exception itself ("Network error.
/// (ClientException with SocketException: Failed host lookup: …)"). That is a
/// developer's message; a student in a hallway with no signal needs to hear
/// that they are offline and what to do about it.
abstract final class NetworkError {
  static const String offline =
      'No internet connection. Check your Wi-Fi or mobile data, then try '
      'again.';

  static const String slow =
      'The connection is too slow — the server did not answer in time. Try '
      'again in a moment.';

  /// [offline] for a connection that could not be opened, [slow] for one
  /// that opened and then waited out the timeout.
  static String messageFor(Object error) =>
      error is TimeoutException ? slow : offline;
}
