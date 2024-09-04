import 'dart:io';
import 'package:power_server/src/structures/enums/path_decode_mode.dart';

extension StringExtention on String {
  static final int _percent = '%'.codeUnitAt(0);
  static final int _slash = '/'.codeUnitAt(0);
  static final int _zero = '0'.codeUnitAt(0);
  static final int _nine = '9'.codeUnitAt(0);
  static final int _upperA = 'A'.codeUnitAt(0);
  static final int _upperF = 'F'.codeUnitAt(0);
  static final int _lowerA = 'a'.codeUnitAt(0);
  static final int _lowerF = 'f'.codeUnitAt(0);

  String get normalizeUrl {
    if (startsWith('/')) {
      return substring('/'.length).normalizeUrl;
    }

    if (endsWith('/')) {
      return substring(0, length - '/'.length).normalizeUrl;
    }

    return this;
  }

  String get normalizeFilePath {
    if(Platform.isWindows){
      if (startsWith('/')) {
        return substring('/'.length).normalizeFilePath;
      }
    }

    if (endsWith('/')) {
      return substring(0, length - '/'.length).normalizeFilePath;
    }

    return this;
  }

  int _decodeHex(int codeUnit) {
    if (_zero <= codeUnit && codeUnit <= _nine) {
      return codeUnit - _zero;
    }

    if (_lowerA <= codeUnit && codeUnit <= _lowerF) {
      return 10 + codeUnit - _lowerA;
    }
    else if (_upperA <= codeUnit && codeUnit <= _upperF) {
      return 10 + codeUnit - _upperA;
    }
    else {
      return -1;
    }
  }

  int? _getCodeUnit(int hex1, int hex2) {
    if (hex1 < 0 || hex1 >= 16) return null;
    if (hex2 < 0 || hex2 >= 16) return null;
    return 16 * hex1 + hex2;
  }

  bool _decode(int? codeUnit, PathDecodeMode mode) {
    if (codeUnit == null) return false;

    switch (mode) {
      case PathDecodeMode.AllButSlash:
        return codeUnit != _slash;
      case PathDecodeMode.SlashOnly:
        return codeUnit == _slash;
    }
  }

  String decodeUri(PathDecodeMode mode) {
    var codes = codeUnits;
    var changed = false;
    var pos = 0;

    while (pos < codes.length) {
      final char = codes[pos];

      if (char == _percent) {
        if (pos + 2 >= length) break;
        final hex1 = _decodeHex(codes[pos + 1]);
        final hex2 = _decodeHex(codes[pos + 2]);
        final codeUnit = _getCodeUnit(hex1, hex2);

        if (_decode(codeUnit, mode)) {
          if (!changed) {
            // make a copy
            codes = codes.toList();
            changed = true;
          }

          codes[pos] = codeUnit!;
          codes.removeRange(pos + 1, pos + 3);
        }
      }

      pos++;
    }

    return changed ? String.fromCharCodes(codes) : this;
  }
}
