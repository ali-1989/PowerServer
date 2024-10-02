import 'package:power_server/src/power_server.dart';
import 'package:power_server/src/extensions/string_extension.dart';
import 'package:power_server/src/core/http_route_param_parser.dart';
import 'package:power_server/src/structures/enums/http_method.dart';
import 'package:power_server/src/structures/enums/path_decode_mode.dart';
import 'package:power_server/src/structures/errors/duplicate_parameter_exception.dart';


class MethodRoute {
  final HttpMethod method;
  final String route;
  late final String? paramKey;
  late final String? paramValue;
  final RouteHandler handler;
  late final RegExp matcher;
  final bool usesWildcard;
  final Map<String, RouteSegmentParam> _params = <String, RouteSegmentParam>{};

  Iterable<RouteSegmentParam> get params => _params.values;

  MethodRoute(this.route, this.handler, this.method, {bool caseSensitive = false}) : usesWildcard = route.contains('*') {
    /// Because in dart 2.18 uri parsing is more permissive, using a \ in regex
    /// is being counted as a /, so we need to add an r and join them together
    /// VERY happy for a more elegant solution here than some random escape
    /// sequence.
    const escapeChar = '@@@^';
    var escapedPath = route.normalizeUrl.replaceAll('\\', escapeChar);
    var segments = Uri.tryParse('/${escapedPath}')?.pathSegments ?? [route.normalizeUrl];
    segments = segments.map((e) => e.replaceAll(escapeChar, '\\')).toList();

    if(escapedPath.contains('/:')){
      int pos = escapedPath.indexOf('\/\:');
      final temp = escapedPath.substring(0, pos);
      paramKey = escapedPath.substring(pos+2);
      escapedPath = temp;
    }
    else {
      paramKey = null;
    }

    var pattern = '^';

    for (var segment in segments) {
      if (segment == '*' && segment != segments.first && segment == segments.last) {
        // Generously match path if last segment is wildcard (*)
        // Example: 'some/path/*' => should match 'some/path', 'some/path/', 'some/path/with/children'
        // but not 'some/pathological'
        pattern += r'(?:/.*|)';
        break;
      }
      else if (segment != segments.first) {
        pattern += '/';
      }

      final param = RouteSegmentParam.tryParse(segment);

      if (param != null) {
        if (_params.containsKey(param.name)) {
          throw DuplicateParameterException(param.name);
        }

        _params[param.name] = param;
        // ignore: prefer_interpolation_to_compose_strings
        segment = r'(?<' + param.name + r'>' + param.pattern + ')';
      }
      else {
        // escape period character
        segment = segment.replaceAll('.', r'\.');
        // wildcard ('*') to anything
        segment = segment.replaceAll('*', '.*?');
      }

      pattern += segment;
    }

    pattern += r'$';
    matcher = RegExp(pattern, caseSensitive: caseSensitive);
  }

  @override
  String toString() => route;
}
///=============================================================================
/// Class used to retain parameter information (name, type, pattern)

class RouteSegmentParam {
  final String name;
  final String pattern;
  final SegmentParamParser? type;
  static final RouteSegmentParamParser paramParser = RouteSegmentParamParser();

  RouteSegmentParam(this.name, this.pattern, this.type);

  dynamic getValue(String value) {
    // path has been decoded already except for '/'
    value = value.decodeUri(PathDecodeMode.SlashOnly);
    return type?.parser(value) ?? value;
  }

  static RouteSegmentParam? tryParse(String segment) {
    /// route param is of the form ":name" or ":name:pattern"
    /// the ":pattern" part can be a regular expression
    /// or a param type name
    if (!segment.startsWith(':')) {
      return null;
    }

    var pattern = '';
    var name = segment.substring(1);
    SegmentParamParser? type;
    final idx = name.indexOf(':');

    if (idx > 0) {
      pattern = name.substring(idx + 1);
      name = name.substring(0, idx);
      final typeName = pattern.toLowerCase();
      type = paramParser.getType(typeName);

      if (type != null) {
        pattern = type.pattern;
      }
    }
    else {
      // anything but a slash
      pattern = r'[^/]+?';
    }

    return RouteSegmentParam(name, pattern, type);
  }
}
