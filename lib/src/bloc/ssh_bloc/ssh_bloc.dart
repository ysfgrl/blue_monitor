import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/ssh_connection.dart';
import '../../store/ssh.dart';

part 'ssh_event.dart';
part 'ssh_state.dart';

class SshBloc extends Bloc<SshEvent, SshState> {
  SshBloc({SshConnectionStore? store})
    : _store = store ?? SshConnectionStore(),
      super(const SshState()) {
    on<SshStorageEvent>(
      _onStorage,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<SshConnectRequested>(_onConnect);
    on<SshDisconnectRequested>(_onDisconnect);
    on<SshNewConnectionRequested>(_onNewConnection);
    on<_SshHostKeyRequested>(_onHostKeyRequested);
    on<SshHostKeyAnswered>(_onHostKeyAnswered);
    on<_SshEnded>(_onEnded);
  }

  final SshConnectionStore _store;
  SSHSocket? _socket;
  SSHClient? _client;
  SSHSession? _session;
  StreamController<Uint8List>? _incoming;
  StreamSubscription<Uint8List>? _stdout;
  StreamSubscription<Uint8List>? _stderr;
  Completer<bool>? _hostKeyDecision;
  int _generation = 0;
  int _challengeId = 0;
  bool _closing = false;
  Future<void>? _closeFuture;
  String? _verificationError;

  bool get _inactive => _closing || isClosed;
  bool _current(int generation) => !_inactive && generation == _generation;

  void _onDisconnect(SshDisconnectRequested event, Emitter<SshState> emit) {
    if (_inactive) return;
    _stopTransport();
    emit(
      state.copyWith(
        status: SshStatus.closed,
        message: 'SSH bağlantısı kapatıldı.',
        clearHostKeyChallenge: true,
      ),
    );
  }

  void _onNewConnection(SshNewConnectionRequested event, Emitter<SshState> emit,) {
    if (_inactive) return;
    _stopTransport();
    emit(
      state.copyWith(
        status: SshStatus.idle,
        clearSession: true,
        clearMessage: true,
        clearHostKeyChallenge: true,
      ),
    );
  }

  void _onHostKeyRequested(_SshHostKeyRequested event, Emitter<SshState> emit) {
    if (_current(event.generation)) {
      emit(state.copyWith(hostKeyChallenge: event.challenge));
    }
  }

  void _onHostKeyAnswered(SshHostKeyAnswered event, Emitter<SshState> emit) {
    if (_inactive) return;
    if (state.hostKeyChallenge?.id != event.id) return;
    final decision = _hostKeyDecision;
    if (decision != null && !decision.isCompleted)
      decision.complete(event.trusted);
    emit(state.copyWith(clearHostKeyChallenge: true));
  }

  void _onEnded(_SshEnded event, Emitter<SshState> emit) {
    if (!_current(event.generation)) return;
    _stopTransport();
    emit(
      state.copyWith(
        status: event.isError ? SshStatus.failed : SshStatus.closed,
        message: event.message,
        clearHostKeyChallenge: true,
      ),
    );
  }

  Future<void> _onStorage(SshStorageEvent event, Emitter<SshState> emit) async {
    if (_inactive) return;
    emit(
      state.copyWith(
        profilesBusy: true,
        clearProfileError: true,
        clearProfileMessage: true,
        clearLastSaved: true,
      ),
    );
    try {
      final List<SshConnection> connections;
      String? message;
      SshConnection? saved;
      switch (event) {
        case SshConnectionsRequested():
          connections = await _store.load();
        case SshConnectionSaved():
          connections = await _store.save(event.connection, event.password);
          saved = event.connection;
          message = 'SSH bağlantısı kaydedildi.';
        case SshConnectionDeleted():
          connections = await _store.delete(event.id);
          message = 'SSH bağlantısı silindi.';
      }
      if (_inactive || emit.isDone) return;
      emit(
        state.copyWith(
          connections: connections,
          profilesReady: true,
          profileMessage: message,
          lastSavedConnection: saved,
        ),
      );
    } catch (error) {
      if (_inactive || emit.isDone) return;
      emit(
        state.copyWith(
          profileError: error is StateError
              ? error.message.toString()
              : 'SSH kayıtları işlenemedi. Güvenli depolamayı kontrol edip yeniden deneyin.',
        ),
      );
    } finally {
      if (!_inactive && !emit.isDone) {
        emit(state.copyWith(profilesBusy: false));
      }
    }
  }

  Future<bool> _verifyHostKey(int generation, SshConnection connection, String type, Uint8List fingerprint,) async {
    final value = utf8.decode(fingerprint);
    final known = await _store.readHostKey(connection.host, connection.port);
    if (!_current(generation)) return false;
    if (known != null) {
      if (known == value) return true;
      _verificationError =
          'Sunucunun SSH anahtarı değişmiş. '
          'Sunucu yöneticisiyle parmak izini doğrulayın.';
      return false;
    }
    final decision = Completer<bool>();
    _hostKeyDecision = decision;
    add(
      _SshHostKeyRequested(
        generation,
        SshHostKeyChallenge(
          id: ++_challengeId,
          host: connection.host,
          port: connection.port,
          type: type,
          fingerprint: value,
        ),
      ),
    );
    final trusted = await decision.future;
    if (!_current(generation)) return false;
    if (!trusted) {
      _verificationError = 'SSH sunucusunun anahtarı onaylanmadı.';
      return false;
    }
    await _store.trustHostKey(connection.host, connection.port, value);
    return _current(generation);
  }

  Future<void> _onConnect(SshConnectRequested event, Emitter<SshState> emit,) async {
    if (_inactive || state.isConnecting || state.isConnected) return;
    final connection = event.connection;
    final generation = ++_generation;
    _verificationError = null;
    emit(
      state.copyWith(
        status: event.testOnly ? SshStatus.testing : SshStatus.connecting,
        activeConnection: connection,
        clearMessage: true,
        clearHostKeyChallenge: true,
      ),
    );
    var password = '';
    try {
      connection.validate();
      password = event.password ?? await _store.passwordFor(connection);
      if (!_current(generation)) return;
      final socket = await SSHSocket.connect(
        connection.host,
        connection.port,
        timeout: const Duration(seconds: 15),
      );
      if (!_current(generation)) {
        socket.destroy();
        return;
      }
      _socket = socket;
      final client = SSHClient(
        socket,
        username: connection.username,
        onPasswordRequest: () => password,
        onVerifyHostKey: (type, fingerprint) =>
            _verifyHostKey(generation, connection, type, fingerprint),
        handshakeTimeout: const Duration(seconds: 60),
        authTimeout: const Duration(seconds: 30),
      );
      _client = client;
      unawaited(_observeClient(generation, client));
      await client.authenticated;
      password = '';
      if (!_current(generation)) return;
      if (event.testOnly) {
        _stopTransport();
        emit(
          state.copyWith(
            status: SshStatus.tested,
            message: 'Bağlantı başarılı. SSH kimlik doğrulaması tamamlandı.',
            clearHostKeyChallenge: true,
          ),
        );
        return;
      }
      final session = await client.shell().timeout(const Duration(seconds: 15));
      if (!_current(generation)) {
        session.close();
        return;
      }
      _session = session;
      // Buffer the first prompt until the shared TerminalPanel subscribes.
      final incoming = StreamController<Uint8List>();
      _incoming = incoming;
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      void receive(Uint8List bytes) {
        if (_current(generation) && !incoming.isClosed) incoming.add(bytes);
      }

      void streamError(Object error) =>
          _queueEnd(generation, _describeError(error), isError: true);
      _stdout = session.stdout.listen(
        receive,
        onError: streamError,
        onDone: () => stdoutDone.complete(),
      );
      _stderr = session.stderr.listen(
        receive,
        onError: streamError,
        onDone: () => stderrDone.complete(),
      );
      emit(
        state.copyWith(status: SshStatus.connected, output: incoming.stream),
      );
      unawaited(
        _observeSession(
          generation,
          session,
          Future.wait([stdoutDone.future, stderrDone.future]),
        ),
      );
    } catch (error) {
      if (!_current(generation)) return;
      final message = _verificationError ?? _describeError(error);
      _stopTransport();
      emit(
        state.copyWith(
          status: SshStatus.failed,
          message: message,
          clearHostKeyChallenge: true,
        ),
      );
    } finally {
      password = '';
    }
  }

  Future<void> _observeClient(int generation, SSHClient client) async {
    try {
      await client.done;
      if (_session == null) _queueEnd(generation, 'SSH bağlantısı kapandı.');
    } catch (error) {
      _queueEnd(
        generation,
        _verificationError ?? _describeError(error),
        isError: true,
      );
    }
  }

  Future<void> _observeSession(int generation, SSHSession session, Future<void> outputDone,) async {
    try {
      await session.done;
      await outputDone;
      final code = session.exitCode;
      _queueEnd(
        generation,
        code == null
            ? 'SSH oturumu kapandı.'
            : 'SSH oturumu kapandı. Çıkış kodu: $code',
      );
    } catch (error) {
      _queueEnd(generation, _describeError(error), isError: true);
    }
  }

  void _queueEnd(int generation, String message, {bool isError = false}) {
    if (_current(generation))
      add(_SshEnded(generation, message, isError: isError));
  }

  String _describeError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FormatException) return error.message;
    if (error is TimeoutException)
      return 'SSH bağlantısı zaman aşımına uğradı.';
    if (error is SSHAuthFailError) {
      return 'Kimlik doğrulanamadı. Kullanıcı adını ve şifreyi kontrol edin.';
    }
    return 'SSH bağlantı hatası: $error';
  }

  void send(Uint8List bytes) {
    if (_inactive || !state.isConnected) return;
    try {
      _session?.write(bytes);
    } catch (error) {
      _queueEnd(_generation, _describeError(error), isError: true);
    }
  }

  void resize(int columns, int rows) {
    if (_inactive || !state.isConnected || columns <= 0 || rows <= 0) return;
    try {
      _session?.resizeTerminal(columns, rows);
    } catch (error) {
      _queueEnd(_generation, _describeError(error), isError: true);
    }
  }

  void _stopTransport() {
    ++_generation;
    final decision = _hostKeyDecision;
    _hostKeyDecision = null;
    if (decision != null && !decision.isCompleted) decision.complete(false);
    _session?.close();
    final client = _client;
    if (client != null) unawaited(client.close().catchError((Object _) {}));
    _socket?.destroy();
    _session = null;
    _client = null;
    _socket = null;
    if (_stdout != null) unawaited(_stdout!.cancel());
    if (_stderr != null) unawaited(_stderr!.cancel());
    _stdout = null;
    _stderr = null;
    final incoming = _incoming;
    _incoming = null;
    if (incoming != null && !incoming.isClosed) unawaited(incoming.close());
  }

  @override
  Future<void> close() => _closeFuture ??= _shutdown();

  Future<void> _shutdown() async {
    _closing = true;
    _stopTransport();
    await super.close();
  }
}
