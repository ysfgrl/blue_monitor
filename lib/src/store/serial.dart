import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';


import '../models/serial_command.dart';



class SavedCommandStore {
  static const _storageKey = 'serial_monitor.saved_commands.v1';
  static const _byteStorageKey = 'serial_monitor.saved_commands.v2';
  late final _preferences = SharedPreferencesAsync();

  Future<List<SerialCommand>> load() async {
    final byteStored = await _preferences.getString(_byteStorageKey);
    if (byteStored != null) {
      final commands = _decodeList(
        byteStored,
      ).map(SerialCommand.fromJson).toList();
      await save(commands);
      await _preferences.remove(_byteStorageKey);
      return commands;
    }
    final stored = await _preferences.getString(_storageKey);
    if (stored == null) return [];
    return _decodeList(stored).map(SerialCommand.fromJson).toList();
  }

  List<dynamic> _decodeList(String stored) {
    final json = jsonDecode(stored);
    if (json is! List) throw const FormatException('Geçersiz komut listesi.');
    return json;
  }

  Future<void> save(List<SerialCommand> commands) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode(commands.map((command) => command.toJson()).toList()),
    );
  }
}
