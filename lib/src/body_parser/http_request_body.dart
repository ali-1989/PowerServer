import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:power_server/power_server.dart';
import 'package:power_server/src/body_parser/http_multipart_form_data.dart';
import 'package:mime/mime.dart';

class HttpBodyHandler extends StreamTransformerBase<HttpRequest, HttpRequestBody> {
  final Encoding _defaultEncoding;

  /// Create a new [HttpBodyHandler] to be used with a [Stream]<[HttpRequest]>,
  /// e.g. a [HttpServer].
  ///
  /// If the page is served using different encoding than UTF-8, set
  /// [defaultEncoding] accordingly. This is required for parsing
  /// `multipart/form-data` content correctly. See the class comment
  /// for more information on `multipart/form-data`.
  HttpBodyHandler({Encoding defaultEncoding = utf8}) : _defaultEncoding = defaultEncoding;


  @override
  Stream<HttpRequestBody> bind(Stream<HttpRequest> stream) {
    var pending = 0;
    var closed = false;

    return stream.transform(
        StreamTransformer.fromHandlers(
            handleData: (request, sink) async {
              pending++;

              try {
                var body = await processRequest(request, null, defaultEncoding: _defaultEncoding);
                sink.add(body);
              }
              catch (e, st) {
                sink.addError(e, st);
              }
              finally {
                pending--;

                if (closed && pending == 0) {
                  sink.close();
                }
              }
            },
            handleDone: (sink) {
            closed = true;

            if (pending == 0) {
              sink.close();
            }
          }));
  }

  /// Process and parse an incoming [HttpRequest].
  ///
  /// The returned [HttpRequestBody] contains a `response` field for accessing
  /// the [HttpResponse].
  /// See [HttpBodyHandler] for more info on [defaultEncoding].
  static Future<HttpRequestBody> processRequest(HttpRequest request, InputOutputModel? inOut, {Encoding defaultEncoding = utf8}) async {
    try {
      final body = await _process(request, request.headers, defaultEncoding, inOut);
      return HttpRequestBody(request, body);
    }
    catch (e) {
      request.response.statusCode = HttpStatus.badRequest; //400
      await request.response.close();

      rethrow;
    }
  }

  /// Process and parse an incoming [HttpClientResponse].
  /// See [HttpBodyHandler] for more info on [defaultEncoding].
  static Future<HttpClientResponseBody> processResponse(HttpClientResponse response, {Encoding defaultEncoding = utf8}) async {
    var body = await _process(response, response.headers, defaultEncoding, null);
    return HttpClientResponseBody(response, body);
  }

  static Future<HttpBody> _process(Stream<List<int>> stream, HttpHeaders headers, Encoding defaultEncoding, InputOutputModel? inOut) async {
    if (headers.contentType == null) {
      return asBinary(stream, inOut);
    }

    final contentType = headers.contentType!;

    try{
      switch (contentType.primaryType) {
        case 'text':
          return asText(stream, contentType, defaultEncoding);

        case 'application':
          switch (contentType.subType) {
            case 'json':
              final body = await asText(stream, contentType, utf8);
              return HttpBody('json', jsonDecode(body.body as String));

            case 'x-www-form-urlencoded':
              final body = await asText(stream, contentType, ascii);
              final map = Uri.splitQueryString(body.body as String, encoding: defaultEncoding);
              final result = <dynamic, dynamic>{};

              for (final key in map.keys) {
                result[key] = map[key];
              }

              return HttpBody('form', result);

            default:
              break;
          }
          break;

        case 'multipart':
          switch (contentType.subType) {
            case 'form-data':
              return asFormData(stream, contentType, defaultEncoding, inOut);

            default:
              break;
          }
          break;

        default:
          break;
      }

      return asBinary(stream, inOut);
    }
    catch (e){
      return Future.error(e);
    }
  }


  static Future<HttpBody> asBinary(Stream<List<int>> stream, InputOutputModel? inOut) async {
    //final bBuilder = await stream.fold<BytesBuilder>(BytesBuilder(), (builder, data) => builder..add(data));
    //return HttpBody('binary', bBuilder.takeBytes());
    String path;

    if(inOut != null){
      path = '${inOut.server.currentPath}/binary_${DateTime.now().millisecondsSinceEpoch}';

      if(inOut.prepareFileUploadPath != null){
        path = await inOut.prepareFileUploadPath!.call(inOut, FileUploadFields()..isFormData = false);
      }
    }
    else {
      final t = File(Platform.script.path); //Platform.executable
      path = '${t.parent.path.normalizeUrl}/binary_${DateTime.now().millisecondsSinceEpoch}';
    }

    final f = File(path);

    await for (final event in stream) {
      f.writeAsBytesSync(event, mode: FileMode.writeOnlyAppend);
    }

    final body = HttpBodyFileUpload(ContentType.binary, 'binary', p.basename(f.path), f);
    return HttpBody('binary', body);
  }

  static Future<HttpBody> asText(Stream<List<int>> stream, ContentType contentType, Encoding defaultEncoding) async {
    Encoding? encoding;
    var charset = contentType.charset;

    if (charset != null) {
      encoding = Encoding.getByName(charset);
    }

    encoding ??= defaultEncoding;

    dynamic buffer = await encoding.decoder.bind(stream).fold<dynamic>(StringBuffer(), (dynamic buffer, data) => buffer..write(data));
    return HttpBody('text', buffer.toString());
  }

  static Future<HttpBody> asFormData(Stream<List<int>> stream, ContentType contentType, Encoding defaultEncoding, InputOutputModel? inOut) async {
    mapper(HttpMultipartFormData multipart) async {
      dynamic data;

      if (multipart.isText) {
        final buffer = await multipart.fold<StringBuffer>(StringBuffer(), (b, dynamic s) => b..write(s));
        data = buffer.toString();
      }
      else {
        //var buffer = await multipart.fold<BytesBuilder>(BytesBuilder(), (b, dynamic d) => b..add(d as List<int>));
        //data = buffer.takeBytes();
        String fileName = multipart.contentDisposition.parameters['filename']!;
        String name = multipart.contentDisposition.parameters['name']!;
        String path;

        if(inOut != null){
          path = '${inOut.server.currentPath}/$fileName';

          if(inOut.prepareFileUploadPath != null){
            final fields = FileUploadFields();
            fields.name = name;
            fields.fileName = fileName;
            path = await inOut.prepareFileUploadPath!.call(inOut, fields);
          }
        }
        else {
          final t = File(Platform.script.path); //Platform.executable
          path = '${t.parent.path.normalizeFilePath}/$fileName';
        }

        final f = File(path);

        await for (final event in multipart) {
          f.writeAsBytesSync(event, mode: FileMode.writeOnlyAppend);
        }

        data = HttpBodyFileUpload(multipart.contentType, name,fileName, f);
      }

      return <dynamic>[multipart.contentDisposition.parameters['name'], data];
    }

    final transformer = MimeMultipartTransformer(contentType.parameters['boundary']!);

    final values1 = transformer.bind(stream).map((part) =>
        HttpMultipartFormData.parse(part, defaultEncoding: defaultEncoding));

    final values2 = await values1.map(mapper) //.cast<Future<List>?>()
        .toList().catchError((e){return <Future<List>>[];});

    final parts = await Future.wait(values2);
    final map = <String, dynamic>{};

    for (final part in parts) {
      map[part[0] as String] = part[1]; // Override existing entries.
    }

    return HttpBody('form', map);
  }
}

