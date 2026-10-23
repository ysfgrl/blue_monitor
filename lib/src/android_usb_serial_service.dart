import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'serial_service.dart';

/// Android USB Host access with writes acknowledged by the native USB driver.
class AndroidUsbSerialService implements SerialService {
  static const _channel = MethodChannel('serial_monitor/usb');
  static const _events = EventChannel('serial_monitor/usb/events');

  final _incoming = StreamController<Uint8List>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  int? _session;
  int _generation = 0;
  bool _opening = false;
  bool _disposed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  void _checkDisposed() {
    if (_disposed) {
      throw const SerialServiceException('Seri port servisi kapatıldı.');
    }
  }

  void _listen() {
    _subscription ??= _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (_disposed || _session == null || event['session'] != _session) {
          return;
        }
        if (event['type'] == 'data') {
          final bytes = event['bytes'] as Uint8List;
          if (bytes.isNotEmpty) _incoming.add(Uint8List.fromList(bytes));
        } else if (event['type'] == 'error') {
          _incoming.addError(
            SerialServiceException(event['message'] as String),
          );
        }
      },
      onError: (Object error) {
        if (!_disposed && _session != null) {
          _incoming.addError(_describe(error));
        }
      },
    );
  }

  @override
  Future<List<PortInfo>> listPorts() async {
    _checkDisposed();
    try {
      _listen();
      final ports = await _channel.invokeListMethod<dynamic>('listPorts') ?? [];
      return ports
          .map(
            (dynamic port) => PortInfo(
              port['name'] as String,
              description: port['description'] as String?,
            ),
          )
          .toList();
    } catch (error) {
      throw _describe(error);
    }
  }

  @override
  Future<void> open(String name, int baudRate) async {
    _checkDisposed();
    if (_opening || _session != null) {
      throw const SerialServiceException('Önce mevcut bağlantıyı kapatın.');
    }
    _opening = true;
    final generation = ++_generation;
    try {
      _listen();
      final session = await _channel.invokeMethod<int>('open', {
        'name': name,
        'baudRate': baudRate,
      });
      if (_disposed || generation != _generation) {
        await _channel.invokeMethod<void>('close');
        throw const SerialServiceException(
          'USB bağlantısı açılırken iptal edildi.',
        );
      }
      if (session == null) {
        throw const SerialServiceException('USB portu açılamadı.');
      }
      _session = session;
    } catch (error) {
      throw _describe(error);
    } finally {
      _opening = false;
    }
  }

  @override
  Future<int> write(Uint8List bytes) async {
    _checkDisposed();
    final session = _session;
    if (session == null) {
      throw const SerialServiceException('Bağlı bir USB portu yok.');
    }
    try {
      final count = await _channel.invokeMethod<int>('write', {
        'session': session,
        'bytes': bytes,
      });
      if (_session != session) {
        throw const SerialServiceException('USB bağlantısı koptu.');
      }
      if (count == null) {
        throw const SerialServiceException(
          'USB sürücüsü yazma sonucu döndürmedi.',
        );
      }
      return count;
    } catch (error) {
      throw _describe(error);
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    _session = null;
    try {
      await _channel.invokeMethod<void>('close');
    } catch (error) {
      throw _describe(error);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await close();
    } finally {
      try {
        await _subscription?.cancel();
      } finally {
        await _incoming.close();
      }
    }
  }

  SerialServiceException _describe(Object error) {
    if (error is SerialServiceException) return error;
    if (error is PlatformException) {
      return SerialServiceException(
        error.message ?? 'Android USB işlemi başarısız.',
      );
    }
    return SerialServiceException('Android USB işlemi başarısız: $error');
  }
}
