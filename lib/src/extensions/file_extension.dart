import 'dart:io';

import 'package:mime_type/mime_type.dart';

extension FileExtension on File {

  String? get mimeType => mime(path);

  ContentType? get contentType {
    final mimeType = this.mimeType;

    if (mimeType != null) {
      final split = mimeType.split('/');
      return ContentType(split[0], split[1]);
    }
    else {
      return null;
    }
  }
}
