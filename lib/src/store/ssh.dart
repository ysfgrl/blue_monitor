import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ssh_connection.dart';

class SshConnectionStore {
  SshConnectionStore()
      : _storage =const FlutterSecureStorage(

            aOptions: AndroidOptions(
                resetOnError: false,

            ),
            // This app does not share Keychain items with other applications.
            mOptions: MacOsOptions(
              accountName: "Blue Monitor",
                label: "Blue Monitor SSH",
                usesDataProtectionKeychain: false
            ),
          );

  static const _connectionsKey = 'blue_monitor.ssh.connections.v1';
  final FlutterSecureStorage _storage;

  Future<List<Map<String, dynamic>>> _readRecords() async {
    final value = await _storage.read(key: _connectionsKey);
    if (value == null) return [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('SSH kayıtları okunamadı.');
    }
    final records = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic> || item['password'] is! String) {
        throw const FormatException('Geçersiz SSH bağlantı kaydı.');
      }
      final connection = SshConnection.fromJson(item);
      if (!ids.add(connection.id)) {
        throw const FormatException('Tekrarlanan SSH bağlantı kaydı.');
      }
      records.add(item);
    }
    return records;
  }

  List<SshConnection> _connections(List<Map<String, dynamic>> records) =>
      List.unmodifiable(records.map(SshConnection.fromJson));

  Future<List<SshConnection>> load() async =>
      _connections(await _readRecords());

  Future<String> passwordFor(SshConnection connection) async {
    final records = await _readRecords();
    final record = records
        .where((item) => item['id'] == connection.id)
        .firstOrNull;
    if (record == null) throw StateError('Kayıtlı SSH bağlantısı bulunamadı.');
    if (!connection.sameEndpoint(SshConnection.fromJson(record))) {
      throw StateError('Sunucu veya kullanıcı değişti. Şifreyi yeniden girin.');
    }
    return record['password'] as String;
  }

  Future<List<SshConnection>> save(SshConnection connection, String? password,) async {
    connection.validate();
    final records = await _readRecords();
    final index = records.indexWhere((item) => item['id'] == connection.id);
    if (password == null) {
      if (index < 0 ||
          !connection.sameEndpoint(SshConnection.fromJson(records[index]))) {
        throw StateError('Bu bağlantı için şifreyi girin.');
      }
      password = records[index]['password'] as String;
    }
    final record = {...connection.toJson(), 'password': password};
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = record;
    }
    // Metadata and passwords are committed together in a single secure value.
    await _storage.write(key: _connectionsKey, value: jsonEncode(records));
    return _connections(records);
  }

  Future<List<SshConnection>> delete(String id) async {
    final records = await _readRecords();
    records.removeWhere((item) => item['id'] == id);
    await _storage.write(key: _connectionsKey, value: jsonEncode(records));
    return _connections(records);
  }

  String _hostKey(String host, int port) =>
      'blue_monitor.ssh.host-key.v1.${base64Url.encode(utf8.encode(jsonEncode([host.toLowerCase(), port])))}';

  Future<String?> readHostKey(String host, int port) async {
    final key = _hostKey(host, port);
    final known = await _storage.read(key: key);
    if (known != null) return known;
    // Preserve fingerprints accepted before SSH settings moved to secure storage.
    final preferences = await SharedPreferences.getInstance();
    final legacyKey = 'ssh.host-key.${jsonEncode([host.toLowerCase(), port])}';
    final legacy = preferences.getString(legacyKey);
    if (legacy == null) return null;
    await _storage.write(key: key, value: legacy);
    await preferences.remove(legacyKey);
    return legacy;
  }

  Future<void> trustHostKey(String host, int port, String fingerprint) =>
      _storage.write(key: _hostKey(host, port), value: fingerprint);
}