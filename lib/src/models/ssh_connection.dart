import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';

class SshConnection extends Equatable {
  const SshConnection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;

  @override
  List<Object?> get props => [id, name, host, port, username];

  String get destination => '$username@$host:$port';

  bool sameEndpoint(SshConnection other) =>
      host.toLowerCase() == other.host.toLowerCase() &&
      port == other.port &&
      username == other.username;

  static String newId() {
    final random = Random.secure();
    return base64Url.encode(List.generate(16, (_) => random.nextInt(256)));
  }

  void validate() {
    if (id.isEmpty ||
        name.trim().isEmpty ||
        host.trim().isEmpty ||
        RegExp(r'\s').hasMatch(host) ||
        port < 1 ||
        port > 65535 ||
        username.trim().isEmpty) {
      throw const FormatException('ssh.invalidConnection');
    }
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
  };

  factory SshConnection.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['name'] is! String ||
        json['host'] is! String ||
        json['port'] is! int ||
        json['username'] is! String) {
      throw const FormatException('ssh.invalidRecord');
    }
    final connection = SshConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
    );
    connection.validate();
    return connection;
  }
}
