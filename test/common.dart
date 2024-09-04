import 'package:alfred/power_server.dart';

extension AlfredTestExtension on Alfred {
  Future<int> listenForTest() async {
    await listen(0);
    return HttpServer!.port;
  }
}
