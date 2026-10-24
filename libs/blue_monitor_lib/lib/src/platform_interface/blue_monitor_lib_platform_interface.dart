import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/serial_config.dart';
import '../models/serial_connection.dart';
import '../models/serial_data.dart';
import '../models/serial_info.dart';
import 'pigeon_blue_monitor_lib.dart';

abstract class BlueMonitorLibPlatform extends PlatformInterface {
  BlueMonitorLibPlatform() : super(token: _token);

  static final Object _token = Object();
  static BlueMonitorLibPlatform _instance = PigeonBlueMonitorLib();

  static BlueMonitorLibPlatform get instance => _instance;

  static set instance(BlueMonitorLibPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<SerialInfo>> getSerialList() =>
      throw UnimplementedError('getSerialList() has not been implemented.');

  Future<List<SerialInfo>> getConnectedPorts() =>
      throw UnimplementedError('getConnectedPorts() has not been implemented.');

  /// Opens the browser's serial device chooser. Call from a user gesture.
  Future<SerialInfo> requestPort() =>
      throw UnsupportedError('requestPort() is only available on web.');

  Future<void> setSignals(
    String path, {
    bool? dataTerminalReady,
    bool? requestToSend,
  }) => throw UnsupportedError('setSignals() is only available on web.');

  Future<void> connect(String path, SerialConfig config) =>
      throw UnimplementedError('connect() has not been implemented.');

  Future<void> disconnect(String path) =>
      throw UnimplementedError('disconnect() has not been implemented.');

  Future<int> write(String path, Uint8List data, int timeoutMs) =>
      throw UnimplementedError('write() has not been implemented.');

  Stream<SerialData> get dataReceived =>
      throw UnimplementedError('dataReceived has not been implemented.');

  Stream<SerialConnection> get connectionChanged =>
      throw UnimplementedError('connectionChanged has not been implemented.');
}
