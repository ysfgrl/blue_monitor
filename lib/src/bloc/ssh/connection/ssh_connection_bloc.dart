import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/ssh_connection.dart';
import '../store.dart';
import 'ssh_session.dart';

part 'ssh_connection_event.dart';
part 'ssh_connection_state.dart';

class SshConnectionBloc extends Bloc<SshConnectionEvent, SshConnectionState> {
  SshConnectionBloc({required SshConnection connection}) : super(SshConnectionState(connection: connection)) {
    on<SshConnectEvent>(_onConnect);
    on<SshConnectedEvent>(_onConnected);
    on<SshDisconnectEvent>(_onDisconnect);
    on<SshHostKeyRequestedEvt>(_onHostKeyRequested);
    on<SshNewSessionEvt>(_newSession);
    on<SshHostKeyAnswered>(_onHostKeyAnswered);
    on<SshErrorDismissed>(_onErrorDismissed);
    on<SshConnectionSessionOpened>(_onSessionOpened);
    on<SshConnectionSessionClosed>(_onSessionClosed);
    on<_SshEnded>(_onEnded);
  }

  Completer<bool>? _keyCompleter;
  SSHClient? client;
  SSHSocket? _socket;
  int _generation = 0;
  int _sessionId = 0;
  bool _closing = false;
  Future<void>? _closeFuture;
  String? _verificationError;
  List<SshSession> get sessions => state.sessions;
  bool _current(int generation) => !_closing && !isClosed && generation == _generation;

  Future<void> _onDisconnect(SshDisconnectEvent event, Emitter<SshConnectionState> emit,) async {
    await _stopTransport();
    if (_closing || emit.isDone) return;
    emit(state.copyWith(status: SshStatus.idle, sessions: const [], isOpeningSession: false, clearHostKeyChallenge: true));
  }

  void _onHostKeyRequested(SshHostKeyRequestedEvt event, Emitter<SshConnectionState> emit,) {
    if (_keyCompleter == null || _keyCompleter!.isCompleted || !state.isConnecting) return;
    emit(state.copyWith(hostKeyChallenge: event.challenge, status: SshStatus.challenge));
  }

  void _onHostKeyAnswered(SshHostKeyAnswered event, Emitter<SshConnectionState> emit,) {
    final decision = _keyCompleter;
    if (state.status != SshStatus.challenge || decision == null || decision.isCompleted) return;
    decision.complete(event.trusted);
    emit(state.copyWith(status: SshStatus.password, clearHostKeyChallenge: true));
  }

  void _onErrorDismissed(SshErrorDismissed event, Emitter<SshConnectionState> emit,) {
    emit(state.copyWith(status: state.hasError ? SshStatus.idle : state.status));
  }

  Future<void> _onEnded(_SshEnded event, Emitter<SshConnectionState> emit,) async {
    if (!_current(event.generation)) return;
    await _stopTransport();
    if (_closing || emit.isDone) return;
    emit(state.copyWith(status: event.isError ? SshStatus.failed : SshStatus.idle, message: event.message, sessions: const [], isOpeningSession: false, clearHostKeyChallenge: true));
  }

  Future<bool> _verifyHostKey(String type, Uint8List fingerprint, int generation,) async {
    if (!_current(generation)) return false;
    try {
      return await _checkHostKey(type, fingerprint, generation);
    } catch (error) {
      if (_current(generation)) _verificationError = _describeError(error);
      return false;
    }
  }

  Future<bool> _checkHostKey(String type, Uint8List fingerprint, int generation,) async {
    final value = utf8.decode(fingerprint);
    final known = await sshKeyStore.readHostKey(state.connection.host, state.connection.port);
    if (!_current(generation)) return false;
    if (known != null) {
      if (known == value) return true;
      _verificationError = 'ssh.hostKeyChanged'.tr();
      return false;
    }
    final decision = Completer<bool>();
    _keyCompleter = decision;
    add(SshHostKeyRequestedEvt(SshHostKeyChallenge(type: type, fingerprint: value)));
    final trusted = await decision.future;
    if (!_current(generation)) return false;
    _keyCompleter = null;
    if (!trusted) {
      _verificationError = 'ssh.hostKeyRejected'.tr();
      return false;
    }
    await sshKeyStore.trustHostKey(state.connection.host, state.connection.port, value);
    return _current(generation);
  }

  void _onConnected(SshConnectedEvent event, Emitter<SshConnectionState> emit,) {
    if (_closing || client == null || !state.isConnecting) return;
    emit(state.copyWith(status: SshStatus.connected, clearHostKeyChallenge: true));
    add(const SshNewSessionEvt());
  }

  Future<void> _onConnect(SshConnectEvent event, Emitter<SshConnectionState> emit,) async {
    if (_closing || state.isConnecting || state.isConnected) return;
    final generation = ++_generation;
    _verificationError = null;
    emit(state.copyWith(status: SshStatus.connecting, clearHostKeyChallenge: true));
    try {
      state.connection.validate();
      final socket = await SSHSocket.connect(state.connection.host, state.connection.port, timeout: const Duration(seconds: 15));
      if (!_current(generation)) {
        socket.destroy();
        return;
      }
      _socket = socket;
      final connectionClient = SSHClient(
        socket,
        username: state.connection.username,
        onPasswordRequest: () => state.connection.password,
        onVerifyHostKey: (type, fingerprint) => _verifyHostKey(type, fingerprint, generation),
        handshakeTimeout: const Duration(seconds: 60),
        authTimeout: const Duration(seconds: 30),
      );
      client = connectionClient;
      unawaited(_observeClient(connectionClient, generation));
      await connectionClient.authenticated;
      if (!_current(generation)) return;
      // Update in this handler so cancellation cannot be followed by a stale connected event.
      emit(state.copyWith(status: SshStatus.connected, clearHostKeyChallenge: true));
      add(const SshNewSessionEvt());
    } catch (error) {
      if (!_current(generation)) return;
      await _stopTransport();
      if (_closing || emit.isDone) return;
      emit(state.copyWith(status: SshStatus.failed, message: _verificationError ?? _describeError(error), sessions: const [], isOpeningSession: false, clearHostKeyChallenge: true));
    }
  }

  Future<void> _observeClient(SSHClient connectionClient, int generation,) async {
    try {
      await connectionClient.done;
      if (_current(generation) && state.isConnected) add(_SshEnded(generation, 'ssh.connectionEnded'.tr()));
    } catch (error) {
      // Authentication errors are handled by _onConnect.
      if (_current(generation) && state.isConnected) add(_SshEnded(generation, _describeError(error), isError: true));
    }
  }

  Future<void> _newSession(SshNewSessionEvt event, Emitter<SshConnectionState> emit,) async {
    await _openSession(++_sessionId, emit);
  }

  Future<void> _onSessionOpened(SshConnectionSessionOpened event, Emitter<SshConnectionState> emit,) async {
    if (sessions.any((session) => session.id == event.id)) return;
    if (event.id > _sessionId) _sessionId = event.id;
    await _openSession(event.id, emit);
  }

  Future<void> _openSession(int id, Emitter<SshConnectionState> emit,) async {
    final connectionClient = client;
    if (_closing || !state.isConnected || state.isOpeningSession || connectionClient == null) return;
    final generation = _generation;
    emit(state.copyWith(isOpeningSession: true));
    // Close a late shell even when the opening timeout has already elapsed.
    var expired = false;
    try {
      final opening = connectionClient.shell().then((shell) {
        if (expired || !_current(generation)) shell.close();
        return shell;
      });
      final shell = await opening.timeout(const Duration(seconds: 15));
      if (!_current(generation) || !state.isConnected) {
        shell.close();
        return;
      }
      final session = SshSession(id: id, session: shell);
      emit(state.copyWith(
          sessions: List.unmodifiable([...sessions, session]),
          isOpeningSession: false
      ));
    } catch (error) {
      expired = true;
      if (!_current(generation) || emit.isDone) return;
      emit(state.copyWith(message: _describeError(error), isOpeningSession: false));
    }
  }

  Future<void> _onSessionClosed(SshConnectionSessionClosed event, Emitter<SshConnectionState> emit,) async {
    final matching = sessions.where((session) => session.id == event.id).firstOrNull;
    if (matching == null) return;
    emit(state.copyWith(sessions: List.unmodifiable(sessions.where((session) => !identical(session, matching)))));
    await matching.stopSession();
  }

  String _describeError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FormatException) return error.message.trExists() ? error.message.tr() : error.message;
    if (error is TimeoutException) return 'ssh.connectionTimedOut'.tr();
    if (error is SSHAuthFailError) return 'ssh.authenticationFailed'.tr();
    return 'ssh.connectionError'.tr(namedArgs: {'error': error.toString()});
  }

  Future<void> _stopTransport() async {
    ++_generation;
    final decision = _keyCompleter;
    _keyCompleter = null;
    if (decision != null && !decision.isCompleted) decision.complete(false);
    final connectionClient = client;
    client = null;
    final socket = _socket;
    _socket = null;
    for (final session in sessions) {
      await session.stopSession();
    }
    socket?.destroy();
    if (connectionClient != null) await connectionClient.close();
  }

  @override
  Future<void> close() => _closeFuture ??= _shutdown();

  Future<void> _shutdown() async {
    _closing = true;
    await _stopTransport();
    await super.close();
  }
}
