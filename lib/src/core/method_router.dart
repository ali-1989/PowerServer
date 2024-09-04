import 'package:power_server/src/power_server.dart';
import 'package:power_server/src/core/method_route.dart';
import 'package:power_server/src/structures/enums/http_method.dart';


class MethodRouter {
  final routes = <MethodRoute>[];

  void get(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.get, path, handler, caseSensitive: caseSensitive);

  /// Create a head route
  ///
  void head(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.head, path, handler, caseSensitive: caseSensitive);

  /// Create a post route
  ///
  void post(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.post, path, handler, caseSensitive: caseSensitive);

  /// Create a put route
  void put(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.put, path, handler, caseSensitive: caseSensitive);

  /// Create a delete route
  ///
  void delete(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.delete, path, handler, caseSensitive: caseSensitive);

  /// Create a patch route
  ///
  void patch(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.patch, path, handler, caseSensitive: caseSensitive);

  /// Create an options route
  ///
  void options(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.options, path, handler, caseSensitive: caseSensitive);

  /// Create a route that listens on all methods
  ///
  void all(String path, RouteHandler handler, {bool caseSensitive = false}) =>
      createRoute(HttpMethod.all, path, handler, caseSensitive: caseSensitive);

  void createRoute(HttpMethod method, String path, RouteHandler handler, {bool caseSensitive = false}) {
    final route = MethodRoute(path, handler, method, caseSensitive: caseSensitive);
    routes.add(route);
  }

  List<String> getRoutes() {
    final ret = <String>[];

    for (final route in routes) {
      late String methodString;

      switch (route.method) {
        case HttpMethod.get:
          methodString = '\x1B[33mGET\x1B[0m';
          break;
        case HttpMethod.post:
          methodString = '\x1B[31mPOST\x1B[0m';
          break;
        case HttpMethod.put:
          methodString = '\x1B[32mPUT\x1B[0m';
          break;
        case HttpMethod.delete:
          methodString = '\x1B[34mDELETE\x1B[0m';
          break;
        case HttpMethod.patch:
          methodString = '\x1B[35mPATCH\x1B[0m';
          break;
        case HttpMethod.options:
          methodString = '\x1B[36mOPTIONS\x1B[0m';
          break;
        case HttpMethod.all:
          methodString = '\x1B[37mALL\x1B[0m';
          break;
        case HttpMethod.head:
          methodString = '\x1B[38mHEAD\x1B[0m';
          break;
        case HttpMethod.copy:
          methodString = '\x1B[39mCOPY\x1B[0m';
          break;
        case HttpMethod.link:
          methodString = '\x1B[40mLINK\x1B[0m';
          break;
        case HttpMethod.unlink:
          methodString = '\x1B[41mUNLINK\x1B[0m';
          break;
        case HttpMethod.purge:
          methodString = '\x1B[42mPURGE\x1B[0m';
          break;
        case HttpMethod.lock:
          methodString = '\x1B[43mUNLOCK\x1B[0m';
          break;
        case HttpMethod.unlock:
          methodString = '\x1B[44mUNLOCK\x1B[0m';
          break;
        case HttpMethod.propfind:
          methodString = '\x1B[45mPROPFIND\x1B[0m';
          break;
        case HttpMethod.view:
          methodString = '\x1B[46mVIEW\x1B[0m';
          break;
      }

      ret.add('${route.route} - $methodString');
    }

    return ret;
  }
}