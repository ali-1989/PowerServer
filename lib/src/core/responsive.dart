import 'dart:convert';
import 'dart:io';

import 'package:power_server/power_server.dart';
import 'package:power_server/src/structures/errors/not_found_exception.dart';

class Responsive {
  InputOutputModel _inOut;
  bool isSend = false;

  Responsive(this._inOut);

  Future<void> sendAndClose(dynamic data) async {
    await send(data);

    /// close after sent
    if(isSend) {
      return _inOut.close();
    }
  }

  // _inOut.response.reasonPhrase >> StateError

  Future<void> send(dynamic userData) async {
    if(isSend) {
      return;
    }

    if (userData is String) {
      _inOut.response.write(userData);
      isSend = true;
    }

    else if (userData is num) {
      _inOut.response.write('$int');
      isSend = true;
    }

    else if (userData is List<int>) {
      if (_inOut.response.headers.contentType == null ||
          _inOut.response.headers.contentType!.value == 'text/plain') {
        _setContentType(ContentType.binary);
      }

      _inOut.response.add(userData);
      isSend = true;
    }

    else if (userData is Map) {
      _setContentType(ContentType.json);
      _inOut.response.write(jsonEncode(userData));
      isSend = true;
    }

    else if (userData is File) {
      if (userData.existsSync()) {
        await ServeFile.serveFile(userData, _inOut);
        isSend = true;
      }
      else {
        throw NotFoundException(_inOut.route ?? userData.path);
      }
    }

    /*else if(data is Directory){//todo.
      _inOut.response.write(jsonEncode(data));
      isSend = true;
    }*/

    else if (userData is WebSocketSession) {
      _inOut.isWebsocket = true;
      //final ws = await WebSocketTransformer.upgrade(_inOut.request).catchError((error) => null);
      final ws = await WebSocketTransformer.upgrade(_inOut.request)
          .then<dynamic>((data) => data)
          .onError((error, stackTrace) => error);

      if (ws is! WebSocket) {
        _inOut.exception = ws;
        _inOut.server.logHandler?.call(ws?.toString() ?? '', LogType.error);
        _inOut.close();
      }
      else {
        _inOut.webSocket = ws;
        isSend = true;
        userData.start(ws);
      }

      return;
    }
    else {
      try {
        if (userData.toJson != null) {
          _setContentType(ContentType.json);
          _inOut.response.write(jsonEncode(userData.toJson()));
          isSend = true;
        }
      }
      on NoSuchMethodError {/**/}

      try {
        if (userData.toJSON != null) {
          _setContentType(ContentType.json);
          _inOut.response.write(jsonEncode(userData.toJSON()));
          isSend = true;
        }
      }
      on NoSuchMethodError /*catch (e)*/ {/**/}
    }
  }

  void _setContentType(ContentType ct) {
    try{
      _inOut.response.headers.contentType = ct;
    }
    catch (e, s){
      _inOut.exception = e;
      _inOut.stackTrace = s;
      _inOut.server.logHandler?.call('E: $e', LogType.error, inOut: _inOut);
      //_inOut.server.onInternalError?.call(e, s, _inOut);
    }
  }
}