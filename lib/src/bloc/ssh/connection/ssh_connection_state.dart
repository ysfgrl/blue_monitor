part of 'ssh_connection_bloc.dart';

enum SshStatus { idle, connecting, challenge,password, connected, failed }

@immutable
class SshHostKeyChallenge extends Equatable {
  const SshHostKeyChallenge({
    required this.type,
    required this.fingerprint,
  });
  final String type;
  final String fingerprint;

  @override
  List<Object?> get props => [type, fingerprint];
}

@immutable
class SshConnectionState extends Equatable {
  const SshConnectionState({
    required this.connection,
    this.status = SshStatus.idle,
    this.message,
    this.hostKeyChallenge,
  });
  final SshConnection connection;
  final SshStatus status;
  final String? message;
  final SshHostKeyChallenge? hostKeyChallenge;

  bool get isConnecting => status == SshStatus.connecting;
  bool get isConnected => status == SshStatus.connected;
  bool get hasError => status == SshStatus.failed;

  @override
  List<Object?> get props => [
    connection,
    status,
    message,
    hostKeyChallenge,
  ];

  SshConnectionState copyWith({
    SshStatus? status,
    String? message,
    SshHostKeyChallenge? hostKeyChallenge,
  }) => SshConnectionState(
    connection: connection,
    status: status ?? this.status,
    message:  message,
    hostKeyChallenge: hostKeyChallenge ?? this.hostKeyChallenge,
  );
}
