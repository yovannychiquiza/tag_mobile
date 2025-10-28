/// Exception thrown when the user's session has expired (401 response)
class SessionExpiredException implements Exception {
  final String message;

  SessionExpiredException(this.message);

  @override
  String toString() => message;
}
