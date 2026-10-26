part of 'ssh_bloc.dart';

enum SshStatus { idle, connecting, testing, tested, connected, closed, failed }

@immutable
class SshHostKeyChallenge extends Equatable {
  const SshHostKeyChallenge({required this.id, required this.host, required this.port, required this.type, required this.fingerprint,});
  final int id;
  final String host;
  final int port;
  final String type;
  final String fingerprint;

  @override
  List<Object?> get props => [id, host, port, type, fingerprint];
}

@immutable
class SshState extends Equatable {
  const SshState({this.status = SshStatus.idle, this.connections = const [], this.profilesReady = false, this.profilesBusy = false, this.profileError, this.profileMessage, this.lastSavedConnection, this.activeConnection, this.output, this.message, this.hostKeyChallenge,});

  final SshStatus status;
  final List<SshConnection> connections;
  final bool profilesReady;
  final bool profilesBusy;
  final String? profileError;
  final String? profileMessage;
  final SshConnection? lastSavedConnection;
  final SshConnection? activeConnection;
  final Stream<Uint8List>? output;
  final String? message;
  final SshHostKeyChallenge? hostKeyChallenge;

  bool get isConnecting =>
      status == SshStatus.connecting || status == SshStatus.testing;
  bool get isConnected => status == SshStatus.connected;
  bool get hasError => status == SshStatus.failed;

  @override
  List<Object?> get props => [
    status,
    connections,
    profilesReady,
    profilesBusy,
    profileError,
    profileMessage,
    lastSavedConnection,
    activeConnection,
    output,
    message,
    hostKeyChallenge,
  ];

  SshState copyWith({SshStatus? status, List<SshConnection>? connections, bool? profilesReady, bool? profilesBusy, String? profileError, bool clearProfileError = false, String? profileMessage, bool clearProfileMessage = false, SshConnection? lastSavedConnection, bool clearLastSaved = false, SshConnection? activeConnection, Stream<Uint8List>? output, bool clearSession = false, String? message, bool clearMessage = false, SshHostKeyChallenge? hostKeyChallenge, bool clearHostKeyChallenge = false,}) => SshState(
    status: status ?? this.status,
    connections: connections ?? this.connections,
    profilesReady: profilesReady ?? this.profilesReady,
    profilesBusy: profilesBusy ?? this.profilesBusy,
    profileError: clearProfileError ? null : profileError ?? this.profileError,
    profileMessage: clearProfileMessage
        ? null
        : profileMessage ?? this.profileMessage,
    lastSavedConnection: clearLastSaved
        ? null
        : lastSavedConnection ?? this.lastSavedConnection,
    activeConnection: clearSession
        ? null
        : activeConnection ?? this.activeConnection,
    output: clearSession ? null : output ?? this.output,
    message: clearMessage ? null : message ?? this.message,
    hostKeyChallenge: clearHostKeyChallenge
        ? null
        : hostKeyChallenge ?? this.hostKeyChallenge,
  );
}
