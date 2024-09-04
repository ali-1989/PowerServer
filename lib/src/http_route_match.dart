import 'package:power_server/src/core/method_route.dart';

class HttpRouteMatch {
  final MethodRoute methodRoute;
  final Map<String, dynamic> params;
  HttpRouteMatch._(this.methodRoute, this.params);

  static HttpRouteMatch? tryParse(MethodRoute route, RegExpMatch match) {
    try {
      final params = <String, dynamic>{};

      for (final param in route.params) {
        var value = match.namedGroup(param.name);

        if (value == null) {
          if (param.pattern != '*') {
            return null;
          }

          value = '';
        }

        params[param.name] = param.getValue(value);
      }

      return HttpRouteMatch._(route, params);
    }
    catch (e) {
      return null;
    }
  }
}
