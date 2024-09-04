import 'dart:async';

import 'package:alfred/power_server.dart';
import 'package:test/test.dart';

void main() {
  late Alfred app;

  setUp(() {
    app = Alfred();
  });

  test('it can compose requests', () async {
    var path = app.methodRoute('path');
    path.get('a', _callback);
    path.post('b', _callback);
    path.put('c', _callback);
    path.patch('d', _callback);
    path.delete('e', _callback);
    path.options('f', _callback);
    path.all('g', _callback);

    expect(app.routes.map((r) => '${r.methodRoute}:${r.method}').toList(), [
      'path/a:Method.get',
      'path/b:Method.post',
      'path/c:Method.put',
      'path/d:Method.patch',
      'path/e:Method.delete',
      'path/f:Method.options',
      'path/g:Method.all',
    ]);
  });

  test('it can compose multiple times', () async {
    app.methodRoute('first/and').methodRoute('second/and').get('third', _callback);
    expect(app.routes.first.methodRoute, 'first/and/second/and/third');
  });

  test('it can handle slashes when composing', () async {
    app.methodRoute('first/').get('/second', _callback);
    app.methodRoute('first').get('/second', _callback);
    app.methodRoute('first/').get('second', _callback);
    app.methodRoute('first').get('second', _callback);
    expect(app.routes.length, 4);
    for (var route in app.routes) {
      expect(route.methodRoute, 'first/second');
    }
  });

  test('it can correctly inherit middleware', () async {
    var mw1 = _callback;
    var mw2 = _callback;

    var first = app.methodRoute('first', middleware: [mw1]);
    first.get('a', _callback);
    first.get('b', _callback);

    var second = first.methodRoute('second', middleware: [mw2]);
    second.get('c', _callback);

    expect(app.routes.length, 3);

    expect(app.routes[0].methodRoute, 'first/a');
    expect(app.routes[0].middleware, [mw1]);

    expect(app.routes[1].methodRoute, 'first/b');
    expect(app.routes[1].middleware, [mw1]);

    expect(app.routes[2].methodRoute, 'first/second/c');
    expect(app.routes[2].middleware, [mw1, mw2]);
  });
}

FutureOr Function(HttpRequest, HttpResponse) get _callback => (req, res) {};
