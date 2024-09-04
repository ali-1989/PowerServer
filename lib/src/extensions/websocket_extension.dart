import 'dart:io';

extension WebSocketExtension on WebSocket {
  void send(dynamic data) => add(data);
}
