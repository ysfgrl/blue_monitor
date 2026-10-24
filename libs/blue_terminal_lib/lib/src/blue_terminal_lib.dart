import 'dart:typed_data';

import 'models/serial_config.dart';
import 'models/serial_connection.dart';
import 'models/serial_data.dart';
import 'models/serial_info.dart';
import 'platform_interface/blue_terminal_lib_platform_interface.dart';

class BlueTerminalLib {
  Future<List<SerialInfo>> getSerialList() =>
      BlueTerminalLibPlatform.instance.getSerialList();

  Future<List<SerialInfo>> getConnectedPorts() =>
      BlueTerminalLibPlatform.instance.getConnectedPorts();

  /// Web only: asks the user to grant access to a serial port.
  /// Call directly from a button handler, before any asynchronous work.
  /// Cancelling the chooser completes with an error.
  Future<SerialInfo> requestPort() =>
      BlueTerminalLibPlatform.instance.requestPort();

  /// Web only: changes DTR/RTS on an open port. Omitted signals are unchanged.
  /// These lines can control reset/boot pins; choose values for your device.
  Future<void> setSignals(
    String path, {
    bool? dataTerminalReady,
    bool? requestToSend,
  }) {
    _validatePath(path);
    if (dataTerminalReady == null && requestToSend == null) {
      throw ArgumentError(
        'Provide at least one of dataTerminalReady or requestToSend.',
      );
    }
    return BlueTerminalLibPlatform.instance.setSignals(
      path,
      dataTerminalReady: dataTerminalReady,
      requestToSend: requestToSend,
    );
  }

  /// Opens [path] for reading and writing. Defaults to 115200 baud, 8N1.
  Future<void> connect(
    String path, {
    SerialConfig config = const SerialConfig(),
  }) {
    _validatePath(path);
    if (config.baudRate <= 0) {
      throw ArgumentError.value(
        config.baudRate,
        'baudRate',
        'Must be positive',
      );
    }
    if (config.dataBits < 5 || config.dataBits > 8) {
      throw ArgumentError.value(config.dataBits, 'dataBits', 'Must be 5 to 8');
    }
    return BlueTerminalLibPlatform.instance.connect(path, config);
  }

  Future<void> disconnect(String path) {
    _validatePath(path);
    return BlueTerminalLibPlatform.instance.disconnect(path);
  }

  /// Returns the number of bytes written. A timeout can cause a partial write.
  Future<int> write(String path, Uint8List data, {int timeoutMs = 1000}) {
    _validatePath(path);
    if (timeoutMs < 0) {
      throw ArgumentError.value(timeoutMs, 'timeoutMs', 'Must be nonnegative');
    }
    return BlueTerminalLibPlatform.instance.write(path, data, timeoutMs);
  }

  /// Raw chunks from all connected ports, identified by their path.
  /// Subscribe before connecting to avoid missing initial bytes.
  Stream<SerialData> get dataReceived =>
      BlueTerminalLibPlatform.instance.dataReceived;

  Stream<SerialConnection> get connectionChanged =>
      BlueTerminalLibPlatform.instance.connectionChanged;

  void _validatePath(String path) {
    if (path.trim().isEmpty || path.contains('\u0000')) {
      throw ArgumentError.value(path, 'path', 'Must be a valid port path');
    }
  }
}
