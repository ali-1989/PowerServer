import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:power_server/src/body_parser/http_body_file_upload.dart';
import 'package:power_server/src/core/in_out_store.dart';
import 'package:power_server/src/core/method_route.dart';
import 'package:power_server/src/core/method_router.dart';
import 'package:power_server/src/extensions/string_extension.dart';
import 'package:power_server/src/http_route_match.dart';
import 'package:power_server/src/structures/enums/http_method.dart';
import 'package:power_server/src/structures/enums/log_type.dart';
import 'package:power_server/src/structures/enums/path_decode_mode.dart';
import 'package:power_server/src/structures/errors/response_exception.dart';
import 'package:power_server/src/structures/errors/not_found_exception.dart';
import 'package:queue/queue.dart';

import 'package:power_server/src/body_parser/http_request_body.dart';
import 'package:power_server/src/core/responsive.dart';
import 'package:power_server/src/extensions/http_response_extension.dart';
import 'package:power_server/src/core/date_formatter.dart';
import 'package:path/path.dart' as p;

part 'package:power_server/src/core/serve_file.dart';
part 'package:power_server/src/structures/models/input_output_model.dart';


typedef RouteHandler = FutureOr<void> Function(InputOutputModel inOut);
typedef ErrorHandler = FutureOr<void> Function(Object error, StackTrace? stackTrace, InputOutputModel inOut);
typedef FileDownloadHandler = FutureOr<bool> Function(InputOutputModel inOut, File file);
typedef LogHandler = void Function(String text, LogType type, {InputOutputModel? inOut});
typedef PrepareFileUploadPath = FutureOr<String> Function(InputOutputModel inOut, FileUploadFields fields);
///=============================================================================
class FileUploadFields {
  bool isFormData = true;
  String? name;
  String? fileName;
}
///=============================================================================
class PowerServer {
  late MethodRouter methodRouter;
  LogHandler? logHandler;
  HttpServer? httpServer;
  /// Optional handler for when a route is not found
  RouteHandler? onNotFound;
  /// Optional handler for when the server throws an unhandled error
  ErrorHandler? onInternalError;
  /// A socket/websocket may not be properly closed after it has done its job.
  /// At intervals, the sockets are checked and closed if necessary and free resources like files.
  Duration periodicCheckToFreeResource = Duration(hours: 6);
  /// The maximum time a socket can remain open.
  Duration maxTimeForUnClosedSocket = Duration(hours: 1);
  /// The maximum time a websocket can remain open.
  Duration maxTimeForUnClosedWebSocket = Duration(hours: 5);
  /// Set files mime type
  final Map mimeTypes = {};

  /// Incoming request queue
  /// Set the number of simultaneous connections being processed at any one time
  /// in the [simultaneousProcessing] param in the constructor
  Queue requestQueue;
  final _beforeRoutingListeners = <RouteHandler>[];
  final _onDoneListeners = <RouteHandler>[];

  int downloadSpeedKbPerSec = 10000; // 10000: 10 MB/s
  FileDownloadHandler? fileDownloadChecker;

  late String currentPath;

  /// Register a listener when a request is complete
  ///
  /// Typically would be used for logging, benchmarking or cleaning up data
  /// used when writing a plugin.
  void registerOnDoneListener(RouteHandler listener) {
    _onDoneListeners.add(listener);
  }

  void removeOnDoneListener(RouteHandler listener) {
    _onDoneListeners.remove(listener);
  }

  void registerBeforeRoutingListener(RouteHandler listener) {
    _beforeRoutingListeners.add(listener);
  }

  void removeBeforeRoutingListener(RouteHandler listener) {
    _beforeRoutingListeners.remove(listener);
  }

  /// Creates a new application.
  ///
  /// [processingQueue] is the number of requests doing work at any one
  /// time. If the amount of unprocessed incoming requests exceed this number,
  /// the requests will be queued.
  PowerServer({
    this.onNotFound,
    this.onInternalError,
    int processingQueue = 50,
  })
      : requestQueue = Queue(parallel: processingQueue),
        methodRouter = MethodRouter()
  {
    final t = File(Platform.script.path);
    currentPath = t.parent.path.normalizeFilePath;
  }


  Future<HttpServer> listen([
    int port = 3000,
    dynamic bindIp = '0.0.0.0',
    bool shared = true,
    int backlog = 0,
    Duration idleTimeout = const Duration(seconds: 1),
  ]) async {
    final server = await HttpServer.bind(
      bindIp,
      port,
      backlog: backlog,
      shared: shared,
    );

    server.idleTimeout = idleTimeout;

    server.listen((HttpRequest request) {
      final inOut = InputOutputModel(this, request, request.response);
      logHandler?.call('D01: [${request.method}] ${request.uri.toString()}', LogType.debug, inOut: inOut);

      // asynchronous unCatch exception
      void _zonedGuardedCatch(obj, stack) async {
        await onInternalError?.call(obj, stack, inOut);
      }

      runZonedGuarded(() {
        requestQueue.add(() => _incomingRequest(inOut));
      }, _zonedGuardedCatch);
    },
      onError: (e){
        logHandler?.call('E06: PowerServer listen error. [on port: ${server.port}]  $e', LogType.error);
      },
      cancelOnError: false,
    );

    logHandler?.call('PowerServer: HTTP Server listening on ${server.address}:${server.port}, currentPath:$currentPath', LogType.info);
    InputOutputModel._startCloseSocketsService(this);

    return httpServer = server;
  }

  Future<HttpServer> listenSecure({
    required SecurityContext securityContext,
    int port = 3000,
    dynamic bindIp = '0.0.0.0',
    bool shared = true,
    int backlog = 0,
    Duration idleTimeout = const Duration(seconds: 1),
  }) async {
    final server = await HttpServer.bindSecure(
      bindIp,
      port,
      securityContext,
      backlog: backlog,
      shared: shared,
    );

    server.idleTimeout = idleTimeout;

    server.listen((HttpRequest request) {
      final inOut = InputOutputModel(this, request, request.response);
      logHandler?.call('D01: [${request.method}] ${request.uri.toString()}', LogType.debug, inOut: inOut);

      void _zonedGuardedCatch(obj, stack) async {
        await onInternalError?.call(obj, stack, inOut);
      }

      runZonedGuarded(() {
        requestQueue.add(() => _incomingRequest(inOut));
      }, _zonedGuardedCatch);
    },
      onError: (e){
        logHandler?.call('E06: PowerServer listening error. [on port: ${server.port}]  $e', LogType.error);
      },
      cancelOnError: false,
    );

    logHandler?.call('PowerServer: HTTPS Server listening on ${server.address}:${server.port}, currentPath:$currentPath', LogType.info);
    InputOutputModel._startCloseSocketsService(this);

    return httpServer = server;
  }

  /// Handles and routes an incoming request
  Future<void> _incomingRequest(InputOutputModel inOut) async {
    inOut.setDownloadSpeed(downloadSpeedKbPerSec);


    /// --- after response done
    unawaited(inOut.request.response.done.then((dynamic _) {
      inOut.isDone = true;

      for (final doneListener in _onDoneListeners) {
        doneListener(inOut);
      }

      InOutStore.releaseStore(inOut.hashCode);
      logHandler?.call('D05: Response sent to client.', LogType.debug, inOut: inOut);
    }));


    /// --- on pre-routing
    for (final beforeRoute in _beforeRoutingListeners) {
      beforeRoute(inOut);
    }

    final httpMethod = _detectMethod(inOut.request);
    final uri = inOut.request.uri.toString();
    final matchesFound = _foundMatch(uri, methodRouter.routes, httpMethod);

    try {
      if (matchesFound.isEmpty) {
        logHandler?.call('D02: No matching route found. $uri', LogType.debug, inOut: inOut);
        await _respondNotFound(inOut);
      }
      else {
        for (final match in matchesFound) {
          if (inOut.isDone) {
            break;
          }

          inOut.routeMatch = match;
          logHandler?.call('D03: current matched route: ${match.methodRoute.route}', LogType.debug, inOut: inOut);

          /// this line is handler for inputs
          await match.methodRoute.handler.call(inOut);
        }


        ///--- check is done
        if (!inOut.isDone) {
          if (inOut.request.response.contentLength < 0 /*&& !nonWildcardRouteMatch*/) {
            await _respondNotFound(inOut);
          }
        }
      }

      if(!inOut.isWebsocket) {
        await inOut.close();
      }
    }
    on NotFoundException catch (e1) {
      inOut.exception = e1;
      await _respondNotFound(inOut);
    }

    on ResponseException catch (e2) {
      try {
        inOut.request.response.statusCode = e2.statusCode;
        inOut.request.response.write(e2.response?.toString());
      }
      on StateError catch (e, s) {
        inOut.exception = e;
        inOut.stackTrace = s;
        logHandler?.call('E01<StateError>: ${e.message}', LogType.error, inOut: inOut);
      }
      catch (e, s) {
        inOut.exception = e;
        inOut.stackTrace = s;
        logHandler?.call('E02: $e', LogType.error, inOut: inOut);
      }

      await inOut.close();
    }

    catch (e3, s) {
      inOut.exception = e3;
      inOut.stackTrace = s;
      logHandler?.call('E03: $e3', LogType.error, inOut: inOut);
      await onInternalError?.call(e3, s, inOut);

      if (onInternalError == null) {
        try {
          inOut.request.response.statusCode = 500;
          inOut.request.response.write(e3);
        }
        catch (e, s) {
          inOut.exception = e;
          inOut.stackTrace = s;
          logHandler?.call('E04: $e', LogType.error, inOut: inOut);
        }
      }

      await inOut.close();
    }
  }

  HttpMethod _detectMethod(HttpRequest request) {
    try {
      return HttpMethod.values.byName(request.method.toLowerCase());
    }
    catch(e) {//on ArgumentError
      return HttpMethod.get;
    }
  }

  static Iterable<HttpRouteMatch> _foundMatch(String path, List<MethodRoute> routes, HttpMethod method) sync* {
    // decode URL path before matching except for "/"
    final inputPath = Uri.parse(path).path.normalizeUrl.decodeUri(PathDecodeMode.AllButSlash);

    for (final route in routes) {
      if (route.method != method && route.method != HttpMethod.all) {
        continue;
      }

      RegExpMatch? match;

      // Match against route RegExp and capture params if valid

      if(route.paramKey != null){
        final pos = inputPath.lastIndexOf('/');
        final url = inputPath.substring(0, pos);
        route.paramValue = inputPath.substring(pos+1);
        match = route.matcher.firstMatch(url);
      }
      else {
        match = route.matcher.firstMatch(inputPath);
      }

      if (match != null) {
        final routeMatch = HttpRouteMatch.tryParse(route, match);

        if (routeMatch != null) {
          yield routeMatch;
        }
      }
    }
  }

  /// Responds request with a NotFound response
  Future<void> _respondNotFound(InputOutputModel inOut) async {
    if (onNotFound != null) {
      await onNotFound!(inOut);
    }
    else {
      inOut.response.statusCode = 404;
      inOut.response.write('404, not found.');
    }

    await inOut.close();
  }

  /// Close the server and clean up any resources
  /// Call this if you are shutting down the server but continuing to run the app.
  Future<dynamic>? close({bool force = true}) {
    return httpServer?.close(force: force);
  }

  static RouteHandler corsHandler({
    int age = 86400,
    String methods = 'POST, GET, PUT, DELETE, OPTIONS, HEAD, PATCH',
    String headers = '*',
    String origin = '*',
  }) {
    return (InputOutputModel inOut) {
      inOut.response.headers.set('Access-Control-Allow-Origin', origin);
      inOut.response.headers.set('Access-Control-Allow-Methods', methods);
      inOut.response.headers.set('Access-Control-Allow-Headers', headers);
      inOut.response.headers.set('Access-Control-Expose-Headers', headers);
      inOut.response.headers.set('Access-Control-Max-Age', age);

      /*if (inOut.request.method == 'OPTIONS') {
        inOut.response.close();
      }*/
    };
  }
}