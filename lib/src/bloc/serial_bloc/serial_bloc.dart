import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:blue_terminal_lib/blue_terminal_lib.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';

part 'serial_event.dart';
part 'serial_state.dart';

class SerialBloc extends Bloc<SerialEvent, SerialState> {
  SerialBloc() : super(const SerialState()) {
    on<SerialPortsRefreshRequested>(_onRefreshPorts);
    on<_SerialPortAccessStarted>(_onPortAccessStarted);
    on<_SerialPortAccessCompleted>(_onPortAccessCompleted);
    on<SerialPortSelected>(_onPortSelected);
    on<SerialTypeChanged>(_onTypeChanged);
    on<SerialConnectionRequested>(_onConnect);
    on<SerialDisconnectionRequested>(_onDisconnect);
    on<SerialSendRequested>(_onSend);
    on<SerialErrorDismissed>(_onErrorDismissed);
    on<SerialHistoryCleared>(_onClearHistory);
    on<_SerialDataReceived>(_onDataReceived);
    on<_SerialConnectionFailed>(_onConnectionFailed);
    on<_SerialWriteCompleted>(_onWriteCompleted);
    _dataSubscription = _serial.dataReceived.listen(
      (event) {
        if (_inactive ||
            !state.isConnected ||
            event.path != _path ||
            event.data.isEmpty)
          return;
        add(
          _SerialDataReceived(
            Uint8List.fromList(event.data).asUnmodifiableView(),
          ),
        );
      },
      onError: (Object error) => _queueConnectionFailure(error),
      onDone: () => _queueConnectionFailure('Veri bağlantısı kapandı.'),
    );
    _connectionSubscription = _serial.connectionChanged.listen(
      (event) {
        if (event.path == _path &&
            event.state == SerialConnectionState.disconnected) {
          final reason = event.error;
          _queueConnectionFailure(
            reason == null || reason.isEmpty
                ? 'Seri port bağlantısı kapandı.'
                : 'Seri port bağlantısı koptu: $reason',
          );
        }
      },
      onError: (Object error) => _queueConnectionFailure(error),
      onDone: () =>
          _queueConnectionFailure('Seri port bağlantı akışı kapandı.'),
    );
  }

  static const maxRecords = 5000;
  static const maxHistoryBytes = 1024 * 1024;
  static const _maxRecordBytes = 4096;

  final _serial = BlueTerminalLib();
  final _incomingBytes = StreamController<Uint8List>.broadcast(sync: true);
  final _pendingWrites = ListQueue<SerialSendRequested>();
  final _sendRequests = HashSet<SerialSendRequested>.identity();
  final _records = ListQueue<TrafficRecord>();
  late final StreamSubscription<SerialData> _dataSubscription;
  late final StreamSubscription<SerialConnection> _connectionSubscription;
  SerialSendRequested? _activeWrite;
  String? _path;
  String? _openingError;
  Future<void>? _connectionAttempt;
  Future<void>? _disconnectFuture;
  Future<void>? _closeFuture;
  bool _portFailed = false;
  bool _closing = false;
  bool _requestingPort = false;

  bool get _inactive => _closing || isClosed;
  Stream<Uint8List> get incomingBytes => _incomingBytes.stream;

  /// Invoke directly from a button so the browser keeps user activation.
  void requestPort() {
    if (_inactive ||
        _requestingPort ||
        state.isRefreshing ||
        state.isBusy ||
        state.isConnected)
      return;
    _requestingPort = true;
    add(const _SerialPortAccessStarted());
    try {
      // Invoke before yielding: the chooser requires a browser user gesture.
      unawaited(
        _serial.requestPort().then<void>(
          (port) {
            if (!_inactive) add(_SerialPortAccessCompleted(port: port));
          },
          onError: (Object error, StackTrace stack) {
            if (!_inactive) add(_SerialPortAccessCompleted(error: error));
          },
        ),
      );
    } catch (error) {
      if (!_inactive) add(_SerialPortAccessCompleted(error: error));
    }
  }

  void _onPortAccessStarted(_SerialPortAccessStarted event, Emitter<SerialState> emit,) {
    _emitState(emit, state.copyWith(isRefreshing: true, clearError: true));
  }

  void _onErrorDismissed(SerialErrorDismissed event, Emitter<SerialState> emit,) {
    if (state.error != null) _emitState(emit, state.copyWith(clearError: true));
  }

  Future<void> _onConnectionFailed(_SerialConnectionFailed event, Emitter<SerialState> emit,) async {
    await _connectionFailed(event.error, emit);
  }

  void _onPortAccessCompleted(_SerialPortAccessCompleted event, Emitter<SerialState> emit,) {
    _requestingPort = false;
    if (_inactive) return;
    final port = event.port;
    if (port != null) {
      _emitState(
        emit,
        state.copyWith(
          ports: [
            for (final existing in state.ports)
              if (existing.path != port.path) existing,
            port,
          ],
          selectedPort: port.path,
          isRefreshing: false,
        ),
      );
    } else {
      final error = event.error;
      if (error is! PlatformException || error.code != 'request-cancelled') {
        _emitState(
          emit,
          state.copyWith(
            error: error == null ? null : _describeError(error),
            isRefreshing: false,
          ),
        );
      } else {
        _emitState(emit, state.copyWith(isRefreshing: false));
      }
    }
  }

  @override
  void onEvent(SerialEvent event) {
    super.onEvent(event);
    if (event is SerialSendRequested) {
      if (_inactive) {
        _completeRequest(event, false);
      } else {
        _sendRequests.add(event);
      }
    }
  }

  void _emitState(Emitter<SerialState> emit, SerialState next) {
    if (!_inactive && !emit.isDone) emit(next);
  }

  void _queueConnectionFailure(Object error) {
    if (_inactive || _path == null) return;
    final message = _describeError(error);
    if (state.status == ConnectionStatus.connecting) {
      _openingError ??= message;
    } else if (state.isConnected && !_portFailed) {
      _portFailed = true;
      add(_SerialConnectionFailed(message));
    }
  }

  void _onTypeChanged(SerialTypeChanged event, Emitter<SerialState> emit) {
    if (state.status == ConnectionStatus.disconnected &&
        state.type != event.type) {
      _emitState(emit, state.copyWith(type: event.type));
    }
  }

  void _onPortSelected(SerialPortSelected event, Emitter<SerialState> emit) {
    if (state.isConnected || state.isBusy || state.selectedPort == event.path)
      return;
    _emitState(
      emit,
      state.copyWith(
        selectedPort: event.path,
        clearSelectedPort: event.path == null,
      ),
    );
  }

  Future<void> _onRefreshPorts(SerialPortsRefreshRequested event, Emitter<SerialState> emit,) async {
    if (_inactive ||
        _requestingPort ||
        state.isRefreshing ||
        state.isConnected ||
        state.isBusy)
      return;
    _emitState(emit, state.copyWith(isRefreshing: true, clearError: true));
    try {
      final ports = await _serial.getSerialList();
      if (_inactive) return;
      final selected = ports.any((port) => port.path == state.selectedPort)
          ? state.selectedPort
          : ports.firstOrNull?.path;
      _emitState(
        emit,
        state.copyWith(
          ports: ports,
          selectedPort: selected,
          clearSelectedPort: selected == null,
        ),
      );
    } catch (error) {
      _emitState(emit, state.copyWith(error: _describeError(error)));
    } finally {
      _emitState(emit, state.copyWith(isRefreshing: false));
    }
  }

  Future<void> _onConnect(SerialConnectionRequested event, Emitter<SerialState> emit,) async {
    if (_inactive ||
        _requestingPort ||
        state.isBusy ||
        state.isConnected ||
        state.isRefreshing ||
        state.isSending)
      return;
    final path = state.selectedPort;
    if (path == null) {
      _emitState(emit, state.copyWith(error: 'Önce bir seri port seçin.'));
      return;
    }
    if (event.baudRate <= 0 || event.baudRate > 2147483647) {
      _emitState(
        emit,
        state.copyWith(
          error: 'Baud hızı 1–2147483647 arasında bir tam sayı olmalı.',
        ),
      );
      return;
    }
    _emitState(
      emit,
      state.copyWith(status: ConnectionStatus.connecting, clearError: true),
    );
    final attempt = _connectPort(path, event.baudRate);
    _connectionAttempt = attempt;
    try {
      await attempt;
      if (_inactive) return;
      final openingError = _openingError;
      if (openingError != null) {
        try {
          await _disconnectPort();
        } catch (_) {
          // Preserve the error received while connecting.
        }
        throw StateError(openingError);
      }
      _emitState(emit, state.copyWith(status: ConnectionStatus.connected));
    } catch (error) {
      _emitState(
        emit,
        state.copyWith(
          error: _describeError(error),
          status: ConnectionStatus.disconnected,
        ),
      );
    } finally {
      _connectionAttempt = null;
      _openingError = null;
    }
  }

  Future<void> _connectPort(String path, int baudRate) async {
    _path = path;
    _openingError = null;
    _portFailed = false;
    var opened = false;
    try {
      await _serial.connect(path, config: SerialConfig(baudRate: baudRate));
      opened = true;
      final error = _openingError;
      if (error != null) throw StateError(error);
    } catch (_) {
      _path = null;
      // Only disconnect if this Bloc successfully opened the port.
      if (opened) {
        try {
          await _serial.disconnect(path);
        } catch (_) {
          // Preserve the original connection error.
        }
      }
      rethrow;
    }
  }

  Future<void> _disconnectPort() async {
    final path = _path;
    _path = null;
    final previous = _disconnectFuture;
    if (previous != null) await previous;
    if (path == null) return;
    final disconnecting = _serial.disconnect(path);
    _disconnectFuture = disconnecting;
    try {
      await disconnecting;
    } finally {
      _disconnectFuture = null;
    }
  }

  Future<void> _onDisconnect(SerialDisconnectionRequested event, Emitter<SerialState> emit,) async {
    if (_inactive || !state.isConnected || state.isSending) return;
    _emitState(emit, state.copyWith(status: ConnectionStatus.disconnecting));
    _cancelPendingWrites();
    try {
      await _disconnectPort();
    } catch (error) {
      _emitState(emit, state.copyWith(error: _describeError(error)));
    } finally {
      _emitState(emit, state.copyWith(status: ConnectionStatus.disconnected));
    }
  }

  void _onDataReceived(_SerialDataReceived event, Emitter<SerialState> emit) {
    if (_inactive || !state.isConnected) return;
    _incomingBytes.add(event.bytes);
    _append(TrafficDirection.rx, event.bytes, emit);
  }

  void _onSend(SerialSendRequested event, Emitter<SerialState> emit) {
    if (_inactive) {
      _completeRequest(event, false);
      return;
    }
    if (!state.isConnected) {
      if (!event.queueIfBusy)
        _emitState(
          emit,
          state.copyWith(error: 'Veri göndermek için önce bağlanın.'),
        );
      _completeRequest(event, false);
      return;
    }
    if (event.bytes.isEmpty || (!event.queueIfBusy && state.isSending)) {
      _completeRequest(event, false);
      return;
    }
    _pendingWrites.add(event);
    _startNextWrite(emit);
  }

  void _startNextWrite(Emitter<SerialState> emit) {
    if (_inactive || _activeWrite != null) return;
    while (_pendingWrites.isNotEmpty) {
      final write = _pendingWrites.removeFirst();
      if (!state.isConnected) {
        _completeRequest(write, false);
        continue;
      }
      _activeWrite = write;
      _emitState(emit, state.copyWith(isSending: true, clearError: true));
      unawaited(_performWrite(write));
      return;
    }
    if (state.isSending) _emitState(emit, state.copyWith(isSending: false));
  }

  Future<void> _performWrite(SerialSendRequested write) async {
    try {
      final path = _path;
      if (path == null || _portFailed || !state.isConnected) {
        throw StateError('Bağlı bir port yok.');
      }
      final count = await _serial.write(path, write.bytes, timeoutMs: 2000);
      if (_inactive || _portFailed || !state.isConnected) {
        throw StateError('Seri port bağlantısı koptu.');
      }
      if (!_inactive) add(_SerialWriteCompleted(write, count: count));
    } catch (error) {
      if (!_inactive) {
        add(_SerialWriteCompleted(write, error: _describeError(error)));
      }
    } finally {
      if (_inactive) _completeRequest(write, false);
    }
  }

  Future<void> _onWriteCompleted(_SerialWriteCompleted event, Emitter<SerialState> emit,) async {
    final write = event.write;
    if (!identical(_activeWrite, write)) return;
    var success = false;
    try {
      if (_inactive || !state.isConnected) return;
      if (event.error != null) {
        await _connectionFailed(event.error!, emit);
        return;
      }
      final count = event.count;
      final bytes = write.bytes;
      if (count == null || count < 0 || count > bytes.length) {
        await _connectionFailed('Geçersiz yazma sonucu alındı.', emit);
        return;
      }
      if (count > 0)
        _append(
          TrafficDirection.tx,
          Uint8List.sublistView(bytes, 0, count),
          emit,
        );
      if (count != bytes.length) {
        await _connectionFailed(
          'Eksik gönderim: ${bytes.length} baytın $count baytı '
          'yazıldı. Bağlantı kapatıldı; cihaz durumunu kontrol edin. '
          'Girdiyi tekrar göndermek daha önce yazılan baytları tekrarlar.',
          emit,
        );
        return;
      }
      success = true;
    } finally {
      _activeWrite = null;
      _completeRequest(write, success);
      _startNextWrite(emit);
    }
  }

  void _completeRequest(SerialSendRequested request, bool success) {
    _sendRequests.remove(request);
    if (!request._completion.isCompleted) request._completion.complete(success);
  }

  void _cancelPendingWrites() {
    while (_pendingWrites.isNotEmpty) {
      _completeRequest(_pendingWrites.removeFirst(), false);
    }
  }

  Future<void> _connectionFailed(Object error, Emitter<SerialState> emit,) async {
    if (_inactive || !state.isConnected) return;
    _emitState(
      emit,
      state.copyWith(
        error: _describeError(error),
        status: ConnectionStatus.disconnecting,
      ),
    );
    _cancelPendingWrites();
    try {
      await _disconnectPort();
    } catch (closeError) {
      _emitState(
        emit,
        state.copyWith(
          error: '${state.error ?? ''}\n${_describeError(closeError)}',
        ),
      );
    } finally {
      _emitState(emit, state.copyWith(status: ConnectionStatus.disconnected));
    }
  }

  void _onClearHistory(SerialHistoryCleared event, Emitter<SerialState> emit) {
    _records.clear();
    _emitState(
      emit,
      state.copyWith(
        records: const [],
        historyBytes: 0,
        rxBytes: 0,
        txBytes: 0,
        droppedRecords: 0,
      ),
    );
  }

  void _append(TrafficDirection direction, Uint8List bytes, Emitter<SerialState> emit,) {
    if (_inactive || bytes.isEmpty) return;
    var historyBytes = state.historyBytes;
    var droppedRecords = state.droppedRecords;
    final timestamp = DateTime.now();
    for (var offset = 0; offset < bytes.length; offset += _maxRecordBytes) {
      final chunk = Uint8List.sublistView(
        bytes,
        offset,
        min(offset + _maxRecordBytes, bytes.length),
      );
      _records.add(TrafficRecord(direction, chunk, timestamp));
      historyBytes += chunk.length;
      while (_records.length > maxRecords || historyBytes > maxHistoryBytes) {
        historyBytes -= _records.removeFirst().bytes.length;
        droppedRecords++;
      }
    }
    _emitState(
      emit,
      state.copyWith(
        records: _records,
        historyBytes: historyBytes,
        droppedRecords: droppedRecords,
        rxBytes:
            state.rxBytes +
            (direction == TrafficDirection.rx ? bytes.length : 0),
        txBytes:
            state.txBytes +
            (direction == TrafficDirection.tx ? bytes.length : 0),
      ),
    );
  }

  @override
  Future<void> close() => _closeFuture ??= _shutdown();

  String _describeError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is PlatformException) {
      final message = error.message ?? error.code;
      if (error.code == 'insecure-context') {
        return 'Web seri port erişimi için uygulamayı HTTPS veya localhost üzerinden açın.';
      }
      if (error.code == 'unsupported-platform') {
        return 'Bu tarayıcı Web Serial desteklemiyor. Masaüstü Chrome ile açın.';
      }
      if (error.code == 'usb-permission-denied') {
        return 'USB erişim izni verilmedi. Yeniden bağlanıp Android izin penceresinde izin verin.';
      }
      if (message.toLowerCase().contains('permission denied')) {
        return 'Port erişim izni yok. Kullanıcınızın cihaz grubuna '
            '(genellikle dialout veya uucp) erişimini kontrol edin.';
      }
      if (error.code == 'port-busy' ||
          message.toLowerCase().contains('device or resource busy')) {
        return 'Port meşgul. Portu kullanan diğer uygulamayı kapatın.';
      }
      return 'Seri port işlemi başarısız: $message';
    }
    return error.toString();
  }

  Future<void> _shutdown() async {
    _closing = true;
    _cancelPendingWrites();
    for (final request in _sendRequests.toList()) {
      _completeRequest(request, false);
    }
    try {
      await Future.wait<void>([
        _dataSubscription.cancel(),
        _connectionSubscription.cancel(),
      ]);
    } finally {
      try {
        // A pending native connect must finish before its port can be closed.
        await _connectionAttempt?.catchError((Object _) {});
        await _disconnectPort().catchError((Object _) {});
      } finally {
        try {
          await _incomingBytes.close();
        } finally {
          await super.close();
        }
      }
    }
  }
}
