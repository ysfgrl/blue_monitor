import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/models/serial_config.dart';
import 'src/models/serial_connection.dart';
import 'src/models/serial_connection_state.dart';
import 'src/models/serial_data.dart';
import 'src/models/serial_flow_control.dart';
import 'src/models/serial_info.dart';
import 'src/models/serial_parity.dart';
import 'src/models/serial_stop_bits.dart';
import 'src/platform_interface/blue_terminal_lib_platform_interface.dart';
import 'src/web/web_serial_bindings.dart';

class _Connection {
  _Connection(this.info, this.port, this.flowControl);

  final SerialInfo info;
  final WebSerialPort port;
  final SerialFlowControl flowControl;
  web.ReadableStreamDefaultReader? reader;
  web.WritableStreamDefaultWriter? writer;
  JSFunction? disconnectListener;
  Future<void>? readTask;
  Future<void>? closing;
  Future<void> writeTail = Future<void>.value();
  bool closeRequested = false;
  bool announced = false;
}

/// Web Serial implementation. Browser device IDs are scoped to this page;
/// the browser does not expose operating-system paths such as COM3 or ttyUSB0.
class BlueTerminalLibWeb extends BlueTerminalLibPlatform {
  final _ports = <String, WebSerialPort>{};
  final _connections = <String, _Connection>{};
  final _opening = <String, Future<void>>{};
  final _data = StreamController<SerialData>.broadcast();
  final _states = StreamController<SerialConnection>.broadcast();
  int _nextPortId = 1;

  static void registerWith(Registrar registrar) {
    BlueTerminalLibPlatform.instance = BlueTerminalLibWeb();
  }

  WebSerial _serial() {
    if (!web.window.isSecureContext) {
      throw PlatformException(
        code: 'insecure-context',
        message: 'Web Serial requires HTTPS or localhost.',
      );
    }
    final serial = browserSerial;
    if (serial == null) {
      throw PlatformException(
        code: 'unsupported-platform',
        message: 'This browser does not support Web Serial.',
      );
    }
    return serial;
  }

  SerialInfo _remember(WebSerialPort port) {
    for (final entry in _ports.entries) {
      if (entry.value.strictEquals(port).toDart) {
        return _info(entry.key, port);
      }
    }
    final path = 'web-serial-${_nextPortId++}';
    _ports[path] = port;
    return _info(path, port);
  }

  SerialInfo _info(String path, WebSerialPort port) {
    final info = port.getInfo();
    final vendor = info.usbVendorId;
    final product = info.usbProductId;
    String hex(int value) => value.toRadixString(16).padLeft(4, '0');
    final name = vendor == null
        ? 'Serial port'
        : 'USB Serial ${hex(vendor)}${product == null ? '' : ':${hex(product)}'}';
    return SerialInfo(name: name, path: path);
  }

  @override
  Future<List<SerialInfo>> getSerialList() async {
    // Browsers only return ports already authorized for this origin.
    // New access must be granted through requestPort() from a user gesture.
    final serial = _serial();
    try {
      final ports = await serial.getPorts().toDart;
      return ports.toDart.map(_remember).toList(growable: false);
    } catch (error) {
      throw PlatformException(code: 'list-failed', message: error.toString());
    }
  }

  @override
  Future<SerialInfo> requestPort() async {
    // No await before requestPort: browser user activation must still be active.
    final request = _serial().requestPort();
    try {
      return _remember(await request.toDart);
    } catch (error) {
      throw PlatformException(
        code: error.toString().contains('NotFoundError')
            ? 'request-cancelled'
            : 'request-failed',
        message: error.toString(),
      );
    }
  }

  @override
  Future<List<SerialInfo>> getConnectedPorts() async => _connections.values
      .where((connection) => connection.announced && !connection.closeRequested)
      .map((connection) => connection.info)
      .toList(growable: false);

  @override
  Future<void> connect(String path, SerialConfig config) {
    _serial();
    if (_connections.containsKey(path) || _opening.containsKey(path)) {
      throw PlatformException(
        code: 'port-busy',
        message: 'Port is already open or opening.',
      );
    }
    final port = _ports[path];
    if (port == null) {
      throw PlatformException(
        code: 'unknown-port',
        message:
            'Select an authorized port using getSerialList() or requestPort().',
      );
    }
    if (config.dataBits != 7 && config.dataBits != 8 ||
        config.stopBits == SerialStopBits.onePointFive ||
        config.parity == SerialParity.mark ||
        config.parity == SerialParity.space ||
        config.flowControl == SerialFlowControl.xonXoff) {
      throw PlatformException(
        code: 'unsupported-config',
        message:
            'Web Serial supports 7/8 data bits, 1/2 stop bits, '
            'none/odd/even parity and none/RTS-CTS flow control.',
      );
    }
    final operation = _open(path, port, config);
    _opening[path] = operation;
    return operation.whenComplete(() {
      _opening.remove(path);
    });
  }

  Future<void> _open(
    String path,
    WebSerialPort port,
    SerialConfig config,
  ) async {
    _Connection? connection;
    try {
      await port
          .open(
            WebSerialOptions(
              baudRate: config.baudRate,
              dataBits: config.dataBits,
              stopBits: config.stopBits == SerialStopBits.two ? 2 : 1,
              parity: config.parity.name,
              flowControl: config.flowControl == SerialFlowControl.rtsCts
                  ? 'hardware'
                  : 'none',
              bufferSize: 65536,
            ),
          )
          .toDart;
      final opened = _Connection(_info(path, port), port, config.flowControl);
      connection = opened;
      _connections[path] = opened;
      final readable = port.readable;
      final writable = port.writable;
      if (readable == null || writable == null) {
        throw StateError('The serial port has no readable or writable stream.');
      }
      opened.writer = writable.getWriter();
      final listener = ((web.Event event) {
        _closeAfterError(opened, 'Serial device disconnected.');
      }).toJS;
      opened.disconnectListener = listener;
      port.addEventListener('disconnect', listener);
      opened.announced = true;
      _states.add(
        SerialConnection(path: path, state: SerialConnectionState.connected),
      );
      opened.readTask = _read(opened);
      // Also surface unexpected setup/interop failures outside reader.read().
      unawaited(
        opened.readTask!.catchError((Object error) {
          _closeAfterError(opened, error.toString());
        }),
      );
    } catch (error) {
      if (connection != null) {
        try {
          await _close(connection, error.toString());
        } catch (_) {}
      }
      throw PlatformException(code: 'open-failed', message: error.toString());
    }
  }

  Future<void> _read(_Connection connection) async {
    while (!connection.closeRequested) {
      // A nonfatal framing/parity/overflow error replaces port.readable.
      // Acquire the current stream again instead of ending the connection.
      final readable = connection.port.readable;
      if (readable == null) {
        _closeAfterError(connection, 'Serial read stream is unavailable.');
        return;
      }
      final reader = readable.getReader() as web.ReadableStreamDefaultReader;
      connection.reader = reader;
      Object? readError;
      StackTrace? readStack;
      try {
        while (!connection.closeRequested) {
          final result = await reader.read().toDart;
          if (result.done) break;
          final value = result.value;
          if (value != null && !connection.closeRequested) {
            final bytes = (value as JSUint8Array).toDart;
            if (bytes.isNotEmpty) {
              _data.add(SerialData(path: connection.info.path, data: bytes));
            }
          }
        }
      } catch (error, stack) {
        readError = error;
        readStack = stack;
      } finally {
        reader.releaseLock();
        connection.reader = null;
      }
      if (connection.closeRequested) return;
      if (readError == null || connection.port.readable == null) {
        _closeAfterError(
          connection,
          readError?.toString() ?? 'Serial read stream ended.',
        );
        return;
      }
      if (_data.hasListener) {
        _data.addError(
          PlatformException(
            code: 'read-error',
            message:
                '${readError.toString()} Reading will resume; check baud rate and framing settings.',
            details: connection.info.path,
          ),
          readStack,
        );
      }
      // Repeated recoverable errors must not spin on the browser event loop.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Future<void> setSignals(
    String path, {
    bool? dataTerminalReady,
    bool? requestToSend,
  }) async {
    final connection = _connections[path];
    if (connection == null || connection.closeRequested) {
      throw PlatformException(
        code: 'port-not-connected',
        message: 'Port is not connected.',
      );
    }
    if (requestToSend != null &&
        connection.flowControl == SerialFlowControl.rtsCts) {
      throw PlatformException(
        code: 'unsupported-signals',
        message: 'RTS is managed by hardware flow control.',
      );
    }
    final WebSerialOutputSignals signals;
    if (dataTerminalReady != null && requestToSend != null) {
      signals = WebSerialOutputSignals(
        dataTerminalReady: dataTerminalReady,
        requestToSend: requestToSend,
      );
    } else if (dataTerminalReady != null) {
      signals = WebSerialOutputSignals(dataTerminalReady: dataTerminalReady);
    } else if (requestToSend != null) {
      signals = WebSerialOutputSignals(requestToSend: requestToSend);
    } else {
      throw ArgumentError('Provide at least one output signal.');
    }
    try {
      await connection.port.setSignals(signals).toDart;
    } catch (error) {
      throw PlatformException(
        code: 'signals-failed',
        message: error.toString(),
      );
    }
  }

  void _closeAfterError(_Connection connection, String error) {
    // Cleanup failures are included in the disconnect event by _closeImpl.
    unawaited(_close(connection, error).catchError((Object _) {}));
  }

  Future<void> _close(_Connection connection, [String? error]) =>
      connection.closing ??= _closeImpl(connection, error);

  Future<void> _closeImpl(_Connection connection, String? reason) async {
    connection.closeRequested = true;
    String? cleanupError;
    final listener = connection.disconnectListener;
    if (listener != null)
      connection.port.removeEventListener('disconnect', listener);
    // Abort pending output so device removal or flow-control backpressure does
    // not leave close() waiting forever for locked streams.
    try {
      await connection.writer?.abort().toDart;
    } catch (error) {
      cleanupError = error.toString();
    } finally {
      connection.writer?.releaseLock();
      connection.writer = null;
    }
    try {
      await connection.reader?.cancel().toDart;
    } catch (error) {
      cleanupError ??= error.toString();
    } finally {
      if (connection.readTask != null) {
        try {
          await connection.readTask;
        } catch (error) {
          cleanupError ??= error.toString();
        }
      } else {
        // Opening can fail after acquiring the reader but before starting it.
        connection.reader?.releaseLock();
        connection.reader = null;
      }
    }
    try {
      await connection.port.close().toDart;
    } catch (error) {
      cleanupError ??= error.toString();
    } finally {
      _connections.remove(connection.info.path);
      if (connection.announced) {
        _states.add(
          SerialConnection(
            path: connection.info.path,
            state: SerialConnectionState.disconnected,
            error: reason ?? cleanupError,
          ),
        );
      }
    }
    if (cleanupError != null && reason == null) {
      throw PlatformException(code: 'close-failed', message: cleanupError);
    }
  }

  @override
  Future<void> disconnect(String path) async {
    // A disconnect issued during open must also release the resulting port.
    try {
      await _opening[path];
    } catch (_) {}
    final connection = _connections[path];
    if (connection != null) await _close(connection);
  }

  @override
  Future<int> write(String path, Uint8List data, int timeoutMs) {
    final connection = _connections[path];
    if (connection == null || connection.closeRequested) {
      throw PlatformException(
        code: 'port-not-connected',
        message: 'Port is not connected.',
      );
    }
    if (timeoutMs <= 0) {
      throw PlatformException(
        code: 'unsupported-timeout',
        message:
            'Web Serial requires a positive write timeout; '
            'nonblocking writes with a byte count are unavailable.',
      );
    }
    final bytes = Uint8List.fromList(data);
    final clock = Stopwatch()..start();
    final operation = connection.writeTail.then<int>((_) async {
      final writer = connection.writer;
      if (connection.closeRequested || writer == null) {
        throw PlatformException(
          code: 'port-closed',
          message: 'Port closed before write completed.',
        );
      }
      final remaining = timeoutMs - clock.elapsedMilliseconds;
      if (remaining <= 0) return 0;
      if (bytes.isEmpty) return 0;
      try {
        await writer
            .write(bytes.toJS)
            .toDart
            .timeout(Duration(milliseconds: remaining));
        return bytes.length;
      } on TimeoutException {
        const message =
            'Write timed out; the port is being closed. '
            'The browser cannot report how many bytes were transmitted.';
        _closeAfterError(connection, message);
        throw PlatformException(code: 'write-timeout', message: message);
      } catch (error) {
        _closeAfterError(connection, error.toString());
        throw PlatformException(
          code: 'write-failed',
          message: error.toString(),
        );
      }
    });
    // Serialize writes while keeping a failed write from poisoning the queue.
    connection.writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  @override
  Stream<SerialData> get dataReceived => _data.stream;

  @override
  Stream<SerialConnection> get connectionChanged => _states.stream;
}
