part of 'ssh_connection_bloc.dart';

@immutable
sealed class SshConnectionEvent extends Equatable {
  const SshConnectionEvent();

  @override
  List<Object?> get props => [];
}

class SshConnectRequested extends SshConnectionEvent {
  const SshConnectRequested();
  @override
  List<Object?> get props => [];
  @override
  bool get stringify => false;
}

class SshDisconnectRequested extends SshConnectionEvent {
  const SshDisconnectRequested();
}

class SshHostKeyAnswered extends SshConnectionEvent {
  const SshHostKeyAnswered(this.trusted);
  final bool trusted;
  @override
  List<Object?> get props => [trusted];
}

class SshHostKeyRequestedEvt extends SshConnectionEvent {
  const SshHostKeyRequestedEvt(this.challenge);
  final SshHostKeyChallenge challenge;
  @override
  List<Object?> get props => [ challenge];
}

class _SshEnded extends SshConnectionEvent {
  const _SshEnded(this.generation, this.message, {this.isError = false});
  final int generation;
  final String message;
  final bool isError;

  @override
  List<Object?> get props => [generation, message, isError];
}
class SshConnectionSessionOpened extends SshConnectionEvent {
  const SshConnectionSessionOpened(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}

class SshConnectionSessionClosed extends SshConnectionEvent {
  const SshConnectionSessionClosed(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}