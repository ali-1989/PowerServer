import 'dart:io';

import 'package:mime_type/mime_type.dart';

import 'file_extension.dart';


extension HttpResponseExtension on HttpResponse {
  void setDownloadHeader({required String filename}) {
    headers.add('Content-Disposition', 'attachment; filename=$filename');
  }

  /// Set the content type from the extension ie. 'pdf'
  bool setContentTypeFromExtension(String extension) {
    final mime = mimeFromExtension(extension);
    
    if (mime != null) {
      final split = mime.split('/');
      headers.contentType = ContentType(split[0], split[1]);
      return true;
    }

    return false;
  }

  void setContentTypeFromFileIfNotExist(File file) {
    final headerContentType = headers.contentType;

    if (headerContentType == null || headerContentType.mimeType == 'text/plain') {
      if (file.contentType != null) {
        headers.contentType = file.contentType;
      }
      else {
        final extension = file.path.split('.').last;

        if (!setContentTypeFromExtension(extension)) {
          headers.contentType = ContentType.binary;
        }
      }
    }
  }
}
