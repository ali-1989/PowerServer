import 'dart:io';

import 'package:mime_type/mime_type.dart';


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

  void setContentTypeFromFileIfNotExist({ContentType? fileContentType, required String fileExtension}) {
    final headerContentType = headers.contentType;

    if (headerContentType == null || headerContentType.mimeType == 'text/plain') {
      if (fileContentType != null) {
        headers.contentType = fileContentType;
      }
      else {
        if (!setContentTypeFromExtension(fileExtension)) {
          headers.contentType = ContentType.binary;
        }
      }
    }
  }
}
