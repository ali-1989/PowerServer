import 'dart:io';

import 'package:mime_type/mime_type.dart';

import 'file_extension.dart';


extension HttpResponseExtension on HttpResponse {
  void setDownloadHeader({required String filename}) {
    headers.add('Content-Disposition', 'attachment; filename=$filename');
  }

  /// Set the content type from the extension ie. 'pdf'
  void setContentTypeFromExtension(String extension) {
    final mime = mimeFromExtension(extension);

    if (mime != null) {
      final split = mime.split('/');
      headers.contentType = ContentType(split[0], split[1]);
    }
  }

  void setContentTypeFromFile(File file) {
    final setContentType = headers.contentType;

    if (setContentType == null || setContentType.mimeType == 'text/plain') {
      final fileContentType = file.contentType;

      if (fileContentType != null) {
        headers.contentType = file.contentType;
      }
      else {
        final extension = file.path.split('.').last;
        final suggestedMime = mimeFromExtension(extension);

        if (suggestedMime != null) {
          setContentTypeFromExtension(extension);
        } else {
          headers.contentType = ContentType.binary;
        }
      }
    }
  }

  /*Future json(Object? json) {
    headers.contentType = ContentType.json;
    write(jsonEncode(json));
    return close();
  }

  Future send(Object? data) {
    write(data);
    return close();
  }*/
}
