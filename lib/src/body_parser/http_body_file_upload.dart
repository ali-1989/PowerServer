import 'dart:io';

class HttpBodyFileUpload {
  /// The filename of the uploaded file.
  final String filename;
  final String name;

  /// The [ContentType] of the uploaded file.
  ///
  /// For `text/*` and `application/json` the [content] field will a String.
  final ContentType? contentType;

  final File file;

  HttpBodyFileUpload(this.contentType, this.name, this.filename, this.file);
}
