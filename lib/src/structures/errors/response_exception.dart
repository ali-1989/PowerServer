class ResponseException implements Exception {
  final Object? response;
  final int statusCode;

  ResponseException(this.statusCode, this.response);

  @override
  String toString(){
    return 'ResponseException:   statusCode:$statusCode, response:$response';
  }
}
