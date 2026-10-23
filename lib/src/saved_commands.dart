import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'byte_codec.dart';

class SavedCommand {
  const SavedCommand({
    required this.name,
    required this.text,
    required this.mode,
    required this.cr,
    required this.lf,
  });

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

  factory SavedCommand.fromJson(Object? json) {
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
      return SavedCommand(
        name: name.trim(),
        text: formatHex(bytes.cast<int>()),
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
    encodeInput(text, inputMode);
    return SavedCommand(
      name: name.trim(),
      text: text,
      mode: inputMode,
      cr: cr,
      lf: lf,
    );
  }
}

class SavedCommandStore {
  static const _storageKey = 'serial_monitor.saved_commands.v1';
  static const _byteStorageKey = 'serial_monitor.saved_commands.v2';
  late final _preferences = SharedPreferencesAsync();

  Future<List<SavedCommand>> load() async {
    final byteStored = await _preferences.getString(_byteStorageKey);
    if (byteStored != null) {
      final commands = _decodeList(
        byteStored,
      ).map(SavedCommand.fromJson).toList();
      await save(commands);
      await _preferences.remove(_byteStorageKey);
      return commands;
    }
    final stored = await _preferences.getString(_storageKey);
    if (stored == null) return [];
    return _decodeList(stored).map(SavedCommand.fromJson).toList();
  }

  List<dynamic> _decodeList(String stored) {
    final json = jsonDecode(stored);
    if (json is! List) throw const FormatException('Geçersiz komut listesi.');
    return json;
  }

  Future<void> save(List<SavedCommand> commands) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode(commands.map((command) => command.toJson()).toList()),
    );
  }
}
