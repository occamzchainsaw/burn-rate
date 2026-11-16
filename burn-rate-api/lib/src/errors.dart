class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Api Exception (status code: $statusCode): $message';
}

class BadRequestException extends ApiException {
  const BadRequestException(String message) : super(400, message);
}

class NotFoundException extends ApiException {
  const NotFoundException(String message) : super(404, message);
}
