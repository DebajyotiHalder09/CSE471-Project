// Stub file for path_provider on web
class StubException implements Exception {
  final String message;
  StubException(this.message);
}

Future<dynamic> getTemporaryDirectory() {
  throw StubException('getTemporaryDirectory is not available on web');
}

