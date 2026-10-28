import 'dart:convert';

import 'package:serial_monitor/src/store/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/ssh_connection.dart';

class SshConnectionStore {
  SshConnectionStore({required this.envId});

  final String envId;
  String get _connectionsKey => 'blue_terminal.ssh.connections.v1.$envId';

  Future<List<Map<String, dynamic>>> _readRecords() async {
    final value = await secureStore.read(key: _connectionsKey);
    if (value == null) return [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('ssh.recordsUnreadable');
    }
    final records = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('ssh.invalidRecord');
      }
      final connection = SshConnection.fromJson(item);
      if (!ids.add(connection.id)) {
        throw const FormatException('ssh.duplicateRecord');
      }
      records.add(item);
    }
    return records;
  }

  List<SshConnection> _connections(List<Map<String, dynamic>> records) =>
      List.unmodifiable(records.map(SshConnection.fromJson));

  Future<List<SshConnection>> load() async =>
      _connections(await _readRecords());

  Future<bool?> save(SshConnection connection) async {
    connection.validate();
    final records = await _readRecords();
    final index = records.indexWhere((item) => item['id'] == connection.id);
    final record = connection.toJson();
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = record;
    }
    await secureStore.write(key: _connectionsKey, value: jsonEncode(records));
    return true;
  }

  Future<List<SshConnection>> delete(String id) async {
    final records = await _readRecords();
    records.removeWhere((item) => item['id'] == id);
    await secureStore.write(key: _connectionsKey, value: jsonEncode(records));
    return _connections(records);
  }
}

class SshKeyStore {
  SshKeyStore();

  String get _prefix => 'blue_terminal.ssh.key.v1';

  String _hostKeySuffix(String host, int port) =>
      base64Url.encode(utf8.encode(jsonEncode([host.toLowerCase(), port])));

  String _hostKey(String host, int port) =>
      '$_prefix.${_hostKeySuffix(host, port)}';

  Future<String?> readHostKey(String host, int port) async {
    final key = _hostKey(host, port);
    final known = await secureStore.read(key: key);
    if (known != null) return known;

    final legacySecureKey =
        'blue_terminal.ssh.host-key.v1.${_hostKeySuffix(host, port)}';
    final legacySecureValue = await secureStore.read(key: legacySecureKey);
    if (legacySecureValue != null) {
      await trustHostKey(host, port, legacySecureValue);
      await secureStore.delete(key: legacySecureKey);
      return legacySecureValue;
    }

    // Preserve fingerprints accepted before SSH settings moved to secure storage.
    final preferences = await SharedPreferences.getInstance();
    final legacyKey = 'ssh.host-key.${jsonEncode([host.toLowerCase(), port])}';
    final legacy = preferences.getString(legacyKey);
    if (legacy == null) return null;
    await secureStore.write(key: key, value: legacy);
    await preferences.remove(legacyKey);
    return legacy;
  }

  Future<void> trustHostKey(String host, int port, String fingerprint) =>
      secureStore.write(key: _hostKey(host, port), value: fingerprint);
}

final sshKeyStore = SshKeyStore();
