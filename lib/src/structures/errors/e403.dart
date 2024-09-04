import 'package:power_server/src/structures/errors/response_exception.dart';

class E403Exception extends ResponseException {
  E403Exception(): super(403, '403 forbidden');
}