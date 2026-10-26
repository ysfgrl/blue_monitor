part of 'local_bloc.dart';

@immutable
sealed class LocalEvent extends Equatable {
  const LocalEvent();
}

class LocalStartEvt extends LocalEvent {
  const LocalStartEvt();
  @override
  List<Object?> get props => [];
}

class LocalExitEvt extends LocalEvent {
  const LocalExitEvt({
    required this.terminalId,
    this.exitCode,
    this.error,
    this.closeTab = true,
  });

  final int terminalId;
  final int? exitCode;
  final String? error;
  final bool closeTab;

  @override
  List<Object?> get props => [terminalId, exitCode, error, closeTab];
}
