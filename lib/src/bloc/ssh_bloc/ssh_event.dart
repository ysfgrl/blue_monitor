part of 'ssh_bloc.dart';

@immutable
sealed class SshEvent extends Equatable {
  const SshEvent();

  @override
  List<Object?> get props => [];
}

sealed class SshStorageEvent extends SshEvent {
  const SshStorageEvent();
}

class SshConnectionsRequested extends SshStorageEvent {
  const SshConnectionsRequested();
}

class SshConnectionSaved extends SshStorageEvent {
  const SshConnectionSaved(this.connection, {this.password});
  final SshConnection connection;
  final String? password;

  @override
  List<Object?> get props => [connection, password];

  // Keep credentials out of event logs.
  @override
  bool get stringify => false;
}

class SshConnectionDeleted extends SshStorageEvent {
  const SshConnectionDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class SshConnectRequested extends SshEvent {
  const SshConnectRequested(
    this.connection, {
    this.password,
    this.testOnly = false,
  });
  final SshConnection connection;
  final String? password;
  final bool testOnly;

  @override
  List<Object?> get props => [connection, password, testOnly];

  @override
  bool get stringify => false;
}

class SshDisconnectRequested extends SshEvent {
  const SshDisconnectRequested();
}

class SshNewConnectionRequested extends SshEvent {
  const SshNewConnectionRequested();
}

class SshHostKeyAnswered extends SshEvent {
  const SshHostKeyAnswered(this.id, {required this.trusted});
  final int id;
  final bool trusted;

  @override
  List<Object?> get props => [id, trusted];
}

class _SshHostKeyRequested extends SshEvent {
  const _SshHostKeyRequested(this.generation, this.challenge);
  final int generation;
  final SshHostKeyChallenge challenge;

  @override
  List<Object?> get props => [generation, challenge];
}

class _SshEnded extends SshEvent {
  const _SshEnded(this.generation, this.message, {this.isError = false});
  final int generation;
  final String message;
  final bool isError;

  @override
  List<Object?> get props => [generation, message, isError];
}
