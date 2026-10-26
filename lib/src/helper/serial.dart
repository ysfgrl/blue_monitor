import 'dart:convert';
import 'dart:typed_data';
import '../models/input_mode.dart';
class SerialHelper {
  static Uint8List encodeInput(String text, InputMode mode) {
    if (text.isEmpty) {
      throw const FormatException('Gönderilecek veri girin.');
    }
    if (mode == InputMode.ascii) {
      if (text.codeUnits.any((value) => value > 127)) {
        throw const FormatException(
          'ASCII yalnızca 0–127 aralığındaki karakterleri destekler. '
              'Türkçe karakterler yerine HEX baytları kullanabilirsiniz.',
        );
      }
      return Uint8List.fromList(ascii.encode(text));
    }
    final compact = text.replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact)) {
      throw const FormatException(
        'HEX için yalnızca 0–9, A–F ve boşluk kullanın. Örnek: 41 42 0D 0A',
      );
    }
    if (compact.length.isOdd) {
      throw const FormatException(
        'Her HEX baytı iki haneli olmalı. Örnek: A yerine 0A.',
      );
    }
    return Uint8List.fromList([
      for (var i = 0; i < compact.length; i += 2)
        int.parse(compact.substring(i, i + 2), radix: 16),
    ]);
  }

  static String formatHex(List<int> bytes) => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  static String formatAscii(List<int> bytes) {
    final result = StringBuffer();
    for (final byte in bytes) {
      switch (byte) {
        case 9:
          result.write(r'\t');
        case 10:
          result.write(r'\n');
        case 13:
          result.write(r'\r');
        case 92:
          result.write(r'\\');
        default:
          result.write(
            byte >= 32 && byte <= 126
                ? String.fromCharCode(byte)
                : '\\x${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}',
          );
      }
    }
    return result.toString();
  }

  /// Plain ASCII for the clipboard; binary bytes remain explicit hex escapes.
  static String asciiClipboardText(List<int> bytes) {
    final result = StringBuffer();
    for (final byte in bytes) {
      result.write(
        byte <= 127
            ? String.fromCharCode(byte)
            : '\\x${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}',
      );
    }
    return result.toString();
  }

}
