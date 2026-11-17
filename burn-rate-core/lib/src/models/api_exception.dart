class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
}

class ApiConnectionException implements Exception {
  const ApiConnectionException(this.message);
  final String message;
}
