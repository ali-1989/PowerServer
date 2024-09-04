import 'dart:async';
import 'dart:io';


/// Convenience wrapper around Dart IO WebSocket implementation
class WebSocketSession {
  late WebSocket websocket;
  FutureOr<void> Function(WebSocket webSocket)? onOpen;
  FutureOr<void> Function(WebSocket webSocket, dynamic data)? onMessage;
  FutureOr<void> Function(WebSocket webSocket)? onClose;
  FutureOr<void> Function(WebSocket webSocket, dynamic error)? onError;

  WebSocketSession({this.onOpen, this.onMessage, this.onClose, this.onError});

  void start(WebSocket webSocket) {
    websocket = webSocket;

    try {
      onOpen?.call(websocket);

      websocket.listen((dynamic data) {
        onMessage?.call(websocket, data);
      },
          onDone: () {
            onClose?.call(websocket);
      },
          onError: (dynamic error) {
            onError?.call(websocket, error);
      });
    }
    catch (e) {
      try {
        websocket.close();
      }
      catch (e) {/**/}

      rethrow;
    }
  }
}

