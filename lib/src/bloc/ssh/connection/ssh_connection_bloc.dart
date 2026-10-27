import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';

import '../../../models/ssh_connection.dart';
import '../store.dart';
import 'ssh_session.dart';
part 'ssh_connection_event.dart';
part 'ssh_connection_state.dart';
typedef SSHHostKeyVerifyHandler = FutureOr<bool> Function(
{
  String host,
  String port,
  String type,
  Uint8List fingerprint,
});


class SshConnectionBloc extends Bloc<SshConnectionEvent, SshConnectionState> {
  SshConnectionBloc({
    required SshConnection connection,
  })
    : super(SshConnectionState(connection: connection)) {
    on<SshConnectRequested>(_onConnect);
    on<SshDisconnectRequested>(_onDisconnect);
    on<SshHostKeyRequestedEvt>(_onHostKeyRequested);
    on<SshHostKeyAnswered>(_onHostKeyAnswered);
    on<_SshEnded>(_onEnded);
  }
  Completer<bool>? _keyCompleter;
  SSHClient? client;
  List<SshSession> sessions = [];
  void _onDisconnect(SshDisconnectRequested event, Emitter<SshConnectionState> emit,) async {
    await _stopTransport();
    emit(state.copyWith(
        status: SshStatus.idle,
        message: 'ssh.connectionClosed'.tr(),
      ));
  }

  void _onHostKeyRequested(SshHostKeyRequestedEvt event, Emitter<SshConnectionState> emit,) {
    emit(state.copyWith(hostKeyChallenge: event.challenge));
  }

  void _onHostKeyAnswered(SshHostKeyAnswered event, Emitter<SshConnectionState> emit,) {
    _keyCompleter?.complete(event.trusted);
    if(event.trusted) {
      emit(state.copyWith(
          status: SshStatus.password
      ));
    }
  }

  void _onEnded(_SshEnded event, Emitter<SshConnectionState> emit) {
    _stopTransport();
    emit(state.copyWith(
      status: event.isError ? SshStatus.failed : SshStatus.idle,
      message: event.message,
    ));
  }

  FutureOr<String?> _askPassword(){
    return state.connection.password;
  }
  Future<bool> _verifyHostKey(String type, Uint8List fingerprint,) async {
    final value = utf8.decode(fingerprint);
    final known = await sshKeyStore.readHostKey(
      state.connection.host,
      state.connection.port,
    );
    if (known != null) {
      if (known == value) return true;
      return false;
    }
    final decision = Completer<bool>();
    _keyCompleter = decision;
    add(SshHostKeyRequestedEvt(SshHostKeyChallenge(
      type: type,
      fingerprint: value,
    )));
    final trusted = await decision.future;
    if (!trusted) {
      return false;
    }
    await sshKeyStore.trustHostKey(state.connection.host, state.connection.port, value);
    return true;
  }

  Future<void> _onConnect(SshConnectRequested event, Emitter<SshConnectionState> emit,) async {
    if (state.isConnecting || state.isConnected) return;
    emit(state.copyWith(
        status: SshStatus.connecting,
      ),
    );
    try {
      await client?.close();
      final socket = await SSHSocket.connect(
        state.connection.host,
        state.connection.port,
        timeout: const Duration(seconds: 15),
      );
      client = SSHClient(
        socket,
        username: state.connection.username,
        onPasswordRequest: _askPassword,
        onVerifyHostKey: _verifyHostKey,
        handshakeTimeout: const Duration(seconds: 60),
        authTimeout: const Duration(seconds: 30),
      );
      await client!.authenticated;
    } catch (error) {
      final message = _describeError(error);
      emit(state.copyWith(
          status: SshStatus.failed,
          message: message,
        ),
      );
    }
  }


  String _describeError(Object error) {
    if (error is FormatException) {
      return error.message.trExists() ? error.message.tr() : error.message;
    }
    if (error is TimeoutException) return 'ssh.connectionTimedOut'.tr();
    if (error is SSHAuthFailError) {
      return 'ssh.authenticationFailed'.tr();
    }
    return 'ssh.connectionError'.tr(namedArgs: {'error': error.toString()});
  }

  Future<void> _stopTransport() async{
    if (_keyCompleter != null && !_keyCompleter!.isCompleted) _keyCompleter!.complete(false);
    await client?.close();
  }


  void _onSessionOpened(SshConnectionSessionOpened event, Emitter<SshConnectionState> emit,) async {
    if(client== null) return;
    if(state.status != SshStatus.connected) return;
    var exist = sessions.firstWhereOrNull((element) => event.id == element.id,);
    if(exist!= null) return;
    sessions.add(SshSession(session: await client!.shell().timeout(
      const Duration(seconds: 15),
    ), id : 0));
  }

  Future<void> _onSessionClosed(SshConnectionSessionClosed event, Emitter<SshConnectionState> emit,) async {
    if(client== null) return;
    if(state.status != SshStatus.connected) return;
    var exist = sessions.firstWhereOrNull((element) => event.id == element.id,);
    if(exist == null) return;
    exist.stopSession();
    sessions.remove(exist);
  }

  @override
  Future<void> close() async{
    await _stopTransport();
    super.close();
  }
}
