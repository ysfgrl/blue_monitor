part of 'local_bloc.dart';

enum LocalStatus { idle, running, unsupported }

@immutable
class LocalTerminalSession extends Equatable {
  const LocalTerminalSession({
    required this.id,
    required this.output,
    this.status = LocalStatus.running,
    this.exitCode,
    this.error,
  });

  final int id;
  final Stream<Uint8List> output;
  final LocalStatus status;
  final int? exitCode;
  final String? error;

  bool get isRunning => status == LocalStatus.running;

  @override
  List<Object?> get props => [id, output, status, exitCode, error];
}

@immutable
class LocalState extends Equatable {
  const LocalState({
    this.status = LocalStatus.idle,
    this.terminals = const [],
    this.error,
  });

  final LocalStatus status;
  final List<LocalTerminalSession> terminals;
  final String? error;

  bool get isRunning => status == LocalStatus.running;

  @override
  List<Object?> get props => [status, terminals, error];
}
