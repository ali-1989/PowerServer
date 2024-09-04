part of 'package:power_server/src/power_server.dart';

class ServeFile {
  static final RegExp _rangeRex = RegExp(r'^bytes=\s*\d*-\d*(,\d*-\d*)*$');

  static Future<void> serveFile(File file, InputOutputModel inOut) async {
    if(!(await inOut.server.fileDownloadChecker?.call(inOut, file)?? true)){
      inOut.response.statusCode = 403;
      inOut.response.write('Can not access.');
      return;
    }

    var modifier = await file.lastModified();
    modifier = modifier.toUtc();
    final formattedModified = DF.formatDate(modifier, [DF.D, ', ', DF.d, ' ', DF.M, ' ', DF.yyyy, ' ', DF.HH, ':', DF.nn, ':', DF.ss, ' ', DF.z]);
    final ifRange = inOut.request.headers.value('If-Range');
    final range = inOut.request.headers.value('range');

    inOut.response.bufferOutput = false;


    /// html or others files
    if(_getDotExtension(file.path).endsWith('html')){
      inOut.response.headers.add('Content-Type', 'text/html; charset=utf-8');
    }
    else {
      inOut.response.setContentTypeFromFile(file);
      inOut.response.setDownloadHeader(filename: _getFileName(file.path));
      inOut.response.headers.add('Accept-Ranges', 'bytes');
      inOut.response.headers.add('Content-Encoding', 'identity');
      inOut.response.headers.set('X-Powered-By', 'Dart, power_server, avicenna');
    }


    /// ETag or LastModified
    if(ifRange != null && ifRange.isNotEmpty) {
      inOut.response.headers.set('ETag', ifRange);
    }
    else {
      inOut.response.headers.set('Last-Modified', formattedModified);
    }


    if(_isEmptyOrNull(range)) {
      final len = await file.length();
      inOut.response.headers.set(HttpHeaders.contentLengthHeader, len);
      inOut._accessFile = await file.open();

      int count = min(104 * inOut._downloadSpeedPerKb, len); // 104 * (100 mills * 10) = 1 kb/sec
      int pos = 0;

      while(pos < len){
        final data = await inOut._accessFile!.read(count);
        inOut.response.add(data);

        pos += data.length;
        count = min(count, len-pos);

        await Future.delayed(Duration(milliseconds: 100));
      }

      inOut._accessFile!.closeSync();
      return; //await inOut.response.addStream(file.openRead());
    }

    /// if part
    else {
      if(!_rangeRex.hasMatch(range!)){
        inOut.response.statusCode = 416;
        inOut.response.write('this rang not supported.');
        return;
      }

      final ranges = range.split('=')[1].split('-');
      final fileLen = await file.length();
      final r1 = int.tryParse(ranges[0])?? 0;
      var r2 = fileLen - 1;

      if (ranges.length > 1 && !_isEmptyOrNull(ranges[1])) {
        r2 = int.tryParse(ranges[1])!;
      }

      final responseRange = 'bytes $r1-$r2/$fileLen';
      var contentLen = (r2-r1)+1;

      inOut.response.headers.set(HttpHeaders.contentRangeHeader, responseRange);
      inOut.response.headers.set(HttpHeaders.contentLengthHeader, contentLen.toString());
      inOut.response.statusCode = 206;

      inOut._accessFile = await file.open();

      contentLen = min(fileLen, contentLen);
      int count = min(104 * inOut._downloadSpeedPerKb, contentLen); // 104 * (100 mills * 10) = 1 kb/sec
      int pos = r1;
      int end = min(fileLen, r2+1);
      inOut._accessFile!.setPositionSync(pos);

      while(pos < end){
        final data = await inOut._accessFile!.read(count);
        inOut.response.add(data);

        pos += data.length; //pos += count;
        count = min(count, end-pos);

        await Future.delayed(Duration(milliseconds: 100));
      }

      inOut._accessFile!.closeSync();
      return; //await inOut.response.addStream(file.openRead(r1, r2+1));
    }
  }

  static _getDotExtension(String path) {
    return p.extension(path);
  }

  static String _getFileName(String path) {
    return p.basename(path);
  }

  static bool _isEmptyOrNull(String? str){
    if (str == null || str.trim().isEmpty) {
      return true;
    }

    return false;
  }
}

/*
if (inOut.request.method == 'POST' || inOut.request.method == 'PUT') {
    //Upload file
    final body = await inOut.body;

    if (body is Map && body['file'] is HttpBodyFileUpload) {
      if (virtualPath != null) {
        inOut.request.preventTraversal('${directory.path}/$virtualPath', directory);
        directory = Directory('${directory.path}/$virtualPath').absolute;
      }

      if (await directory.exists() == false) {
      await directory.create(recursive: true);
  }

  final fileName = (body['file'] as HttpBodyFileUpload).filename;
  final fileToWrite = File('${directory.path}/$fileName');

  inOut.request.preventTraversal(fileToWrite.path, directory);

  await fileToWrite.writeAsBytes((body['file'] as HttpBodyFileUpload).content as List<int>);
  final publicPath ="${inOut.request.requestedUri.toString() + (virtualPath != null ? '/$virtualPath' : '')}/$fileName";

  await inOut.response.json({'path': publicPath});
  }
  }

 */