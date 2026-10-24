import 'dart:typed_data';

import '../models/serial_config.dart';
import '../models/serial_connection.dart';
import '../models/serial_connection_state.dart';
import '../models/serial_data.dart';
import '../models/serial_info.dart';
import 'blue_terminal_lib_messages.g.dart' as messages;
import 'blue_terminal_lib_platform_interface.dart';

/// Adapts generated messages to the public API.
class PigeonBlueTerminalLib extends BlueTerminalLibPlatform {
  final messages.BlueTerminalLibApi _api = messages.BlueTerminalLibApi();

  late final Stream<SerialData> _dataReceived = messages
      .serialDataReceived()
      .map((event) => SerialData(path: event.path, data: event.data));
  late final Stream<SerialConnection> _connectionChanged = messages
      .serialConnectionChanged()
      .map(
        (event) => SerialConnection(
          path: event.path,
          state: SerialConnectionState.values.byName(event.state.name),
          error: event.error,
        ),
      );

  SerialInfo _info(messages.SerialInfoMessage message) =>
      SerialInfo(name: message.name, path: message.path);

  @override
  Future<List<SerialInfo>> getSerialList() async =>
      (await _api.getSerialList()).map(_info).toList(growable: false);

  @override
  Future<List<SerialInfo>> getConnectedPorts() async =>
      (await _api.getConnectedPorts()).map(_info).toList(growable: false);

  @override
  Future<void> connect(String path, SerialConfig config) => _api.connect(
    path,
    messages.SerialConfigMessage(
      baudRate: config.baudRate,
      dataBits: config.dataBits,
      stopBits: messages.SerialStopBits.values.byName(config.stopBits.name),
      parity: messages.SerialParity.values.byName(config.parity.name),
      flowControl: messages.SerialFlowControl.values.byName(
        config.flowControl.name,
      ),
    ),
  );

  @override
  Future<void> disconnect(String path) => _api.disconnect(path);

  @override
  Future<int> write(String path, Uint8List data, int timeoutMs) =>
      _api.write(path, data, timeoutMs);

  @override
  Stream<SerialData> get dataReceived => _dataReceived;

  @override
  Stream<SerialConnection> get connectionChanged => _connectionChanged;
}
