import 'dart:io';

extension RequestHelpers on HttpRequest {
  /*
  InOutStore get store {
    InOutStore.storeData[this] ??= InOutStore();
    return InOutStore.storeData[this]!;
  }

  void preventTraversal(String filePath, Directory absDir) {
    final check = File(filePath).absolute;
    final absDirPath = p.canonicalize(absDir.path);
    if (!p.canonicalize(check.path).startsWith(absDirPath)) {
      log(() => 'Server directory traversal attempt: ${check.path}');
      throw E403Exception();
    }
  }
   */

  /// Get the content type
  ContentType? get contentType => headers.contentType;
}
