import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'serial_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, disconnecting }

enum TrafficDirection { rx, tx }

class TrafficRecord {
  TrafficRecord(this.direction, List<int> bytes, this.timestamp)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final TrafficDirection direction;
  final Uint8List bytes;
  final DateTime timestamp;
}

class MonitorController extends ChangeNotifier {
  MonitorController(this._service) {
    _subscription = _service.incoming.listen(
      (bytes) {
        if (!isConnected || bytes.isEmpty) return;
        final snapshot = Uint8List.fromList(bytes).asUnmodifiableView();
        _incomingBytes.add(snapshot);
        _append(TrafficDirection.rx, snapshot);
      },
      onError: (Object error) {
        if (isConnected) unawaited(_connectionFailed(error));
      },
      onDone: () {
        if (isConnected) {
          unawaited(_connectionFailed('Veri bağlantısı kapandı.'));
        }
      },
    );
  }

  static const maxRecords = 5000;
  static const maxHistoryBytes = 1024 * 1024;
  static const _maxRecordBytes = 4096;

  final SerialService _service;
  final _incomingBytes = StreamController<Uint8List>.broadcast(sync: true);
  final _pendingWrites = ListQueue<_PendingWrite>();
  late final StreamSubscription<Uint8List> _subscription;
  final _records = ListQueue<TrafficRecord>();
  List<TrafficRecord>? _snapshot;
  List<PortInfo> _ports = [];
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _selectedPort;
  String? _error;
  bool _refreshing = false;
  bool _sending = false;
  bool _disposed = false;
  int _historyBytes = 0;
  int _rxBytes = 0;
  int _txBytes = 0;
  int _droppedRecords = 0;
  int _session = 0;

  List<PortInfo> get ports => List.unmodifiable(_ports);
  List<TrafficRecord> get records => _snapshot ??= List.unmodifiable(_records);
  ConnectionStatus get status => _status;
  String? get selectedPort => _selectedPort;
  String? get error => _error;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isBusy =>
      _status == ConnectionStatus.connecting ||
      _status == ConnectionStatus.disconnecting;
  bool get isRefreshing => _refreshing;
  bool get isSending => _sending;
  int get rxBytes => _rxBytes;
  int get txBytes => _txBytes;
  int get historyBytes => _historyBytes;
  int get droppedRecords => _droppedRecords;
  Stream<Uint8List> get incomingBytes => _incomingBytes.stream;
  int get session => _session;

  void selectPort(String? name) {
    if (isConnected || isBusy) return;
    _selectedPort = name;
    _notify();
  }

  Future<void> refreshPorts() async {
    if (_disposed || _refreshing || isConnected || isBusy) return;
    _refreshing = true;
    _error = null;
    _notify();
    try {
      final ports = await _service.listPorts();
      if (_disposed) return;
      _ports = ports;
      if (!_ports.any((port) => port.name == _selectedPort)) {
        _selectedPort = _ports.firstOrNull?.name;
      }
    } catch (error) {
      if (!_disposed) _error = error.toString();
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> connect(int baudRate) async {
    if (_disposed || isBusy || isConnected || _refreshing) return;
    _error = null;
    if (_selectedPort == null) {
      _error = 'Önce bir seri port seçin.';
      _notify();
      return;
    }
    if (baudRate <= 0 || baudRate > 2147483647) {
      _error = 'Baud hızı 1–2147483647 arasında bir tam sayı olmalı.';
      _notify();
      return;
    }
    _status = ConnectionStatus.connecting;
    _notify();
    try {
      await _service.open(_selectedPort!, baudRate);
      if (_disposed) {
        await _service.close();
        return;
      }
      _session++;
      _status = ConnectionStatus.connected;
    } catch (error) {
      if (!_disposed) {
        _error = error.toString();
        _status = ConnectionStatus.disconnected;
      }
    }
    _notify();
  }

  Future<void> disconnect() async {
    if (_disposed || !isConnected || _sending) return;
    _status = ConnectionStatus.disconnecting;
    _cancelPendingWrites();
    _notify();
    try {
      await _service.close();
    } catch (error) {
      if (!_disposed) _error = error.toString();
    } finally {
      _status = ConnectionStatus.disconnected;
      _notify();
    }
  }

  Future<bool> send(Uint8List bytes) async {
    if (_disposed || _sending) return false;
    if (!isConnected) {
      _error = 'Veri göndermek için önce bağlanın.';
      _notify();
      return false;
    }
    return sendRaw(bytes);
  }

  /// Serializes terminal keystrokes and pastes without dropping busy writes.
  Future<bool> sendRaw(Uint8List bytes) {
    if (_disposed || !isConnected || bytes.isEmpty) {
      return Future.value(false);
    }
    final pending = _PendingWrite(Uint8List.fromList(bytes), _session);
    _pendingWrites.add(pending);
    if (!_sending) unawaited(_drainWrites());
    return pending.result.future;
  }

  Future<void> _drainWrites() async {
    _sending = true;
    _error = null;
    _notify();
    try {
      while (_pendingWrites.isNotEmpty) {
        final pending = _pendingWrites.removeFirst();
        final success = !_disposed && isConnected && pending.session == _session
            ? await _writeBytes(pending.bytes, pending.session)
            : false;
        pending.result.complete(success);
      }
    } finally {
      _sending = false;
      _notify();
    }
  }

  Future<bool> _writeBytes(Uint8List bytes, int session) async {
    try {
      final count = await _service.write(bytes);
      if (_disposed || !isConnected || session != _session) return false;
      if (count < 0 || count > bytes.length) {
        throw const SerialServiceException('Geçersiz yazma sonucu alındı.');
      }
      if (count > 0) {
        _append(TrafficDirection.tx, Uint8List.sublistView(bytes, 0, count));
      }
      if (count != bytes.length) {
        _error =
            'Eksik gönderim: ${bytes.length} baytın $count baytı '
            'yazıldı. Bağlantı kapatıldı; cihaz durumunu kontrol edin. '
            'Girdiyi tekrar göndermek daha önce yazılan baytları tekrarlar.';
        await _closeAfterFailure();
        return false;
      }
      return true;
    } catch (error) {
      if (!_disposed && isConnected && session == _session) {
        await _connectionFailed(error);
      }
      return false;
    }
  }

  void _cancelPendingWrites() {
    _session++;
    while (_pendingWrites.isNotEmpty) {
      _pendingWrites.removeFirst().result.complete(false);
    }
  }

  Future<void> _connectionFailed(Object error) async {
    if (_disposed) return;
    _error = error.toString();
    await _closeAfterFailure();
  }

  Future<void> _closeAfterFailure() async {
    _status = ConnectionStatus.disconnecting;
    _cancelPendingWrites();
    _notify();
    try {
      await _service.close();
    } catch (error) {
      if (!_disposed) _error = '${_error ?? ''}\n$error';
    } finally {
      _status = ConnectionStatus.disconnected;
      _notify();
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void clearHistory() {
    _records.clear();
    _snapshot = null;
    _historyBytes = 0;
    _rxBytes = 0;
    _txBytes = 0;
    _droppedRecords = 0;
    _notify();
  }

  void _append(TrafficDirection direction, Uint8List bytes) {
    if (bytes.isEmpty) return;
    if (direction == TrafficDirection.rx) {
      _rxBytes += bytes.length;
    } else {
      _txBytes += bytes.length;
    }
    final timestamp = DateTime.now();
    for (var offset = 0; offset < bytes.length; offset += _maxRecordBytes) {
      final chunk = Uint8List.sublistView(
        bytes,
        offset,
        min(offset + _maxRecordBytes, bytes.length),
      );
      _records.add(TrafficRecord(direction, chunk, timestamp));
      _historyBytes += chunk.length;
      while (_records.length > maxRecords || _historyBytes > maxHistoryBytes) {
        _historyBytes -= _records.removeFirst().bytes.length;
        _droppedRecords++;
      }
    }
    _snapshot = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelPendingWrites();
    unawaited(_subscription.cancel());
    unawaited(_incomingBytes.close());
    // Dispose is synchronous in Flutter; consume teardown errors here.
    unawaited(_service.dispose().catchError((Object _) {}));
    super.dispose();
  }
}

class _PendingWrite {
  _PendingWrite(this.bytes, this.session);

  final Uint8List bytes;
  final int session;
  final result = Completer<bool>();
}
