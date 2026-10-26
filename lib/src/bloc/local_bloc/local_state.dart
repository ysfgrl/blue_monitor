part of 'local_bloc.dart';

enum LocalStatus {
  idle,
  running,
  exited,
  unsupported
}

@immutable
class LocalState extends Equatable {
  const LocalState({
    this.status = LocalStatus.idle,
    this.output,
    this.exitCode,
    this.error,
    this.shell,
  });

  final LocalStatus status;
  final Stream<Uint8List>? output;
  final int? exitCode;
  final String? error;
  final LocalShell? shell;

  bool get isRunning => status == LocalStatus.running;

  @override
  List<Object?> get props => [status,shell ,output, exitCode, error];
}
