import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'serial_service.dart';

class LibSerialService implements SerialService {
  final _incoming = StreamController<Uint8List>.broadcast();
  SerialPort? _port;
  Timer? _reader;
  bool _disposed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<List<PortInfo>> listPorts() async {
    try {
      final names = SerialPort.availablePorts..sort();
      return names.map((name) {
        final port = SerialPort(name);
        try {
          // A metadata error must not hide an otherwise usable port.
          try {
            return PortInfo(name, description: port.description);
          } catch (_) {
            return PortInfo(name);
          }
        } finally {
          port.dispose();
        }
      }).toList();
    } catch (error) {
      throw _describe(error);
    }
  }

  @override
  Future<void> open(String name, int baudRate) async {
    if (_disposed) {
      throw const SerialServiceException('Seri port servisi kapatıldı.');
    }
    if (_port != null) {
      throw const SerialServiceException('Önce mevcut bağlantıyı kapatın.');
    }
    SerialPort? port;
    var opened = false;
    try {
      port = SerialPort(name);
      if (!port.openReadWrite()) {
        throw SerialPort.lastError ??
            const SerialServiceException('Port açılamadı.');
      }
      opened = true;
      // libserialport.dart owns and disposes its cached config with the port.
      final config = port.config
        ..baudRate = baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none);
      port.config = config;
      _port = port;
      // Nonblocking reads on one isolate avoid sharing native port ownership
      // across reader-isolate startup and disposal. Each tick is bounded.
      _reader = Timer.periodic(const Duration(milliseconds: 16), (_) {
        try {
          final available = port!.bytesAvailable;
          // This getter returns native error codes without throwing.
          if (available < 0) {
            throw SerialPort.lastError ??
                const SerialServiceException('Seri port bağlantısı koptu.');
          }
          if (available > 0) {
            final bytes = port.read(min(available, 65536));
            if (bytes.isNotEmpty) _incoming.add(bytes);
          }
        } catch (error) {
          _reader?.cancel();
          _incoming.addError(_describe(error));
        }
      });
    } catch (error) {
      if (port != null) {
        try {
          if (opened) port.close();
        } finally {
          port.dispose();
        }
      }
      _port = null;
      throw _describe(error);
    }
  }

  @override
  Future<int> write(Uint8List bytes) async {
    final port = _port;
    if (port == null) {
      throw const SerialServiceException('Bağlı bir port yok.');
    }
    try {
      // Nonblocking: retain the exact accepted count without stalling the UI.
      return port.write(bytes);
    } catch (error) {
      throw _describe(error);
    }
  }

  @override
  Future<void> close() async {
    _reader?.cancel();
    _reader = null;
    final port = _port;
    _port = null;
    if (port == null) return;
    try {
      if (!port.close()) {
        throw SerialPort.lastError ??
            const SerialServiceException('Port kapatılamadı.');
      }
    } catch (error) {
      throw _describe(error);
    } finally {
      port.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await close();
    } finally {
      await _incoming.close();
    }
  }

  SerialServiceException _describe(Object error) {
    if (error is SerialServiceException) return error;
    if (error is OSError) {
      return SerialServiceException(switch (error.errorCode) {
        13 =>
          'Port erişim izni yok. Kullanıcınızın cihaz grubuna '
              '(genellikle dialout veya uucp) erişimini kontrol edin.',
        16 => 'Port meşgul. Portu kullanan diğer uygulamayı kapatın.',
        2 || 5 || 6 || 19 =>
          'Cihaza erişilemiyor. Kabloyu ve port listesini '
              'kontrol edip yeniden bağlanın. (${error.message})',
        _ => 'Seri port hatası: ${error.message} (${error.errorCode})',
      });
    }
    return SerialServiceException('Seri port işlemi başarısız: $error');
  }
}
