import 'serial_connection_state.dart';

class SerialConnection {
  const SerialConnection({required this.path, required this.state, this.error});

  final String path;
  final SerialConnectionState state;
  final String? error;
}
