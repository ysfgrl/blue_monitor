import 'dart:typed_data';

class PortInfo {
  const PortInfo(this.name, {this.description});

  final String name;
  final String? description;

  String get label => description == null || description!.isEmpty
      ? name
      : '$name — $description';
}

class SerialServiceException implements Exception {
  const SerialServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns at most one port. Incoming errors indicate a lost connection.
abstract interface class SerialService {
  Stream<Uint8List> get incoming;
  Future<List<PortInfo>> listPorts();
  Future<void> open(String name, int baudRate);

  /// Returns the number of bytes accepted by the driver, not a device ACK.
  Future<int> write(Uint8List bytes);
  Future<void> close();
  Future<void> dispose();
}
