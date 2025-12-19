//library l01_power_server;

part of 'package:power_server/src/power_server.dart';

class InputOutputModel {
  static final List<InputOutputModel> _inOutHolder = [];
  late DateTime startTime;
  PowerServer server;
  HttpRequest request;
  HttpResponse response;
  HttpRequestBody? _requestBody;
  late Responsive _responsive;
  bool _isDone = false;
  bool _isClosed = false;
  bool _isInternalErrorCall = false;
  bool isWebsocket = false;
  int _downloadSpeedPerKb = 0; //this is set later
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
    final form = await bodyAsForm;

    try {
      return form.firstWhere((elm) => elm.partName == name).data;
    }
    catch (e){
      return null;
    }
  }

  /// [kbPerSec] is unit of speed for download. min is 1 and max is 1000000 KB.
  void setDownloadSpeed(int kbPerSec){
    if(kbPerSec < 1 || kbPerSec > 1000000){
      throw Exception('download speed must be between 1 to 1,000,000 KB.');
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

  void setResponseAsFile({String? fileName, File? file}){
    ServeFile.setHeaderAsFile(this, fileName: fileName, file: file);
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

  FutureOr<dynamic> get body async {
    if (_cachedBody != null) {
      return _cachedBody;
    }

    if(exception != null){
      return null;
    }

    _requestBody = await HttpBodyHandler.processRequest(request, this);
    _cachedBody = _requestBody!.body;
    return _cachedBody;
  }

  /// Parse the body, and convert it to a json map if can.
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

  Future<List<FormBody>> get bodyAsForm async {
    final t = await body;

    if(t is List && t.isNotEmpty && t[0] is FormBody){
      return t as List<FormBody>;
    }

    return [];
  }

  Future<HttpBodyType> get bodyType async {
    await body;
    return _requestBody!.type;
  }

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