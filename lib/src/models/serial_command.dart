

import 'input_mode.dart';
import '../helper/serial.dart';
class SerialCommand {
  const SerialCommand({required this.name, required this.text, required this.mode, required this.cr, required this.lf,});

  final String name;
  final String text;
  final InputMode mode;
  final bool cr;
  final bool lf;

  Map<String, Object> toJson() => {
    'name': name,
    'text': text,
    'mode': mode.name,
    'cr': cr,
    'lf': lf,
  };

  factory SerialCommand.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz komut kaydı.');
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Geçersiz komut kaydı.');
    }
    // Keep commands saved by the short-lived byte-only format readable.
    if (json.containsKey('bytes')) {
      final bytes = json['bytes'];
      if (bytes is! List ||
          bytes.isEmpty ||
          bytes.any((byte) => byte is! int || byte < 0 || byte > 255)) {
        throw const FormatException('Geçersiz komut kaydı.');
      }
      return SerialCommand(
        name: name.trim(),
        text: SerialHelper.formatHex(bytes.cast<int>()),
        mode: InputMode.hex,
        cr: false,
        lf: false,
      );
    }
    final text = json['text'];
    final mode = json['mode'];
    final cr = json['cr'];
    final lf = json['lf'];
    if (text is! String ||
        (mode != 'ascii' && mode != 'hex') ||
        cr is! bool ||
        lf is! bool) {
      throw const FormatException('Geçersiz komut kaydı.');
    }
    final inputMode = mode == 'hex' ? InputMode.hex : InputMode.ascii;
    SerialHelper.encodeInput(text, inputMode);
    return SerialCommand(
      name: name.trim(),
      text: text,
      mode: inputMode,
      cr: cr,
      lf: lf,
    );
  }
}