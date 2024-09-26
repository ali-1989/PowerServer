//library l01_power_server;

part of 'package:power_server/src/power_server.dart';

class InputOutputModel {
  static final List<InputOutputModel> _inOutHolder = [];
  late DateTime startTime;
  PowerServer server;
  HttpRequest request;
  HttpResponse response;
  late Responsive _responsive;
  bool _isDone = false;
  bool _isClosed = false;
  bool isWebsocket = false;
  int _downloadSpeedPerKb = 10000;
  WebSocket? webSocket;
  RandomAccessFile? _accessFile;
  PrepareFileUploadPath? _prepareFileUploadPath;
  static Timer? _timer;

  InputOutputModel(this.server, this.request, this.response){
   _responsive = Responsive(this);
   startTime = DateTime.now();
   _inOutHolder.add(this);
  }

  bool get isDone => _isDone;

  set isDone (bool val){
    _isDone = val;

    if(_isDone){
      _inOutHolder.remove(this);
    }
  }

  PrepareFileUploadPath? get prepareFileUploadPath => _prepareFileUploadPath;
  set prepareFileUploadPath (PrepareFileUploadPath? handler){
    _prepareFileUploadPath = handler;
  }

  Future<HttpBodyFileUpload?> getUploadedFile(String name) async {
    return (await bodyAsJsonMap)[name];
  }

  /// [kbPerSec] is unit of speed for download. min is 1 and max is 1000000.
  void setDownloadSpeed(int kbPerSec){
    if(kbPerSec < 1 || kbPerSec > 1000000){
      throw Exception('download speed must be between 1 to 1000000.');
    }

    _downloadSpeedPerKb = kbPerSec;
  }
  //----------------------------------------------------------------------------
  /// data can be 'string', 'num', 'List<int>', 'File', 'Map'
  Future<void> sendAndClose(dynamic data){
    return _responsive.sendAndClose(data);
  }

  Future<void> send(dynamic data){
    return _responsive.send(data);
  }

  Future<dynamic> close() async {
    if(_isClosed){
      return;
    }

    try{
      _accessFile?.closeSync();
      //await request.response.flush(); no. take error
    }
    catch(e, s){
      if(e is! FileSystemException || !(e as IOException).toString().contains('File closed')){
        exception = e;
        stackTrace = s;
        server.logHandler?.call('PowerServer: Error in closing file. $e', LogType.error, inOut: this);
      }
    }

    try{
      webSocket?.close();
    }
    catch(e, s){
      exception = e;
      stackTrace = s;
      server.logHandler?.call('PowerServer: Error in closing WebSocket. $e', LogType.error, inOut: this);
    }

    try{
      return request.response.close();
    }
    catch(e, s){
      exception = e;
      stackTrace = s;
      server.logHandler?.call('PowerServer: Error in closing Socket. $e', LogType.error, inOut: this);
    }
    finally {
      _isClosed = true;
    }
  }

  InOutStore get keyValueStore {
    InOutStore.storeData[this.hashCode] ??= InOutStore();
    return InOutStore.storeData[this.hashCode]!;
  }

  /// the matched route of the current request
  HttpRouteMatch? routeMatch;
  Map<String, dynamic>? get params => routeMatch?.params;
  String? get route => routeMatch?.methodRoute.route;

  /// Get the intercepted exception
  dynamic exception;
  StackTrace? stackTrace;
  dynamic _cachedBody;

  Future<Object?> get body async {
    if (_cachedBody != null) {
      return _cachedBody;
    }

    if(exception != null){
      return null;
    }

    _cachedBody = (await HttpBodyHandler.processRequest(request, this)).body;
    return _cachedBody;
  }

  /// Parse the body, and convert it to a json map
  Future<Map<String, dynamic>> get bodyAsJsonMap async {
    final t = await body;

    if(t is Map){
      return Map<String, dynamic>.from(t);
    }

    if(t is String){
      return Map<String, dynamic>.from(jsonDecode(t));
    }

    return {};
  }

  /// Parse the body, and convert it to a json list
  Future<List<dynamic>> get bodyAsJsonList async => (await body) as List;

  static void _startCloseSocketsService(PowerServer powerServer){
    if(_timer != null && _timer!.isActive){
      return;
    }

    _timer = Timer.periodic(powerServer.periodicCheckToFreeResource, (timer) {
      final socketNow = DateTime.now().subtract(powerServer.maxTimeForUnClosedSocket);
      final websocketNow = DateTime.now().subtract(powerServer.maxTimeForUnClosedWebSocket);

      for(final inOut in _inOutHolder){
        if(inOut.isWebsocket){
          if(inOut.startTime.isBefore(websocketNow)){
            powerServer.logHandler?.call('W2: An unclosed websocket was found.', LogType.warning);
            inOut.close();
          }
        }

        else if(inOut.startTime.isBefore(socketNow)){
          powerServer.logHandler?.call('W1: An unclosed socket was found.', LogType.warning);
          inOut.close();
        }
      }
    });
  }
}