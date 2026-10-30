part of 'ssh_connection_bloc.dart';

enum SshStatus { idle, connecting, challenge,password, connected, failed }

@immutable
class SshHostKeyChallenge extends Equatable {
  const SshHostKeyChallenge({required this.type, required this.fingerprint,});
  final String type;
  final String fingerprint;

  @override
  List<Object?> get props => [type, fingerprint];
}

@immutable
class SshConnectionState extends Equatable {
  const SshConnectionState({required this.connection, this.status = SshStatus.idle, this.message, this.hostKeyChallenge, this.sessions = const [], this.isOpeningSession = false,});
  final SshConnection connection;
  final SshStatus status;
  final String? message;
  final SshHostKeyChallenge? hostKeyChallenge;
  final List<SshSession> sessions;
  final bool isOpeningSession;

  bool get isConnecting => status == SshStatus.connecting || status == SshStatus.challenge || status == SshStatus.password;
  bool get isConnected => status == SshStatus.connected;
  bool get hasError => status == SshStatus.failed;

  @override
  List<Object?> get props => [
    connection,
    status,
    message,
    hostKeyChallenge,
    sessions,
    isOpeningSession,
  ];

  SshConnectionState copyWith({SshStatus? status, String? message, SshHostKeyChallenge? hostKeyChallenge, bool clearHostKeyChallenge = false, List<SshSession>? sessions, bool? isOpeningSession,}) => SshConnectionState(
    connection: connection,
    status: status ?? this.status,
    message:  message,
    hostKeyChallenge: clearHostKeyChallenge ? null : hostKeyChallenge ?? this.hostKeyChallenge,
    sessions: sessions ?? this.sessions,
    isOpeningSession: isOpeningSession ?? this.isOpeningSession,
  );
}
