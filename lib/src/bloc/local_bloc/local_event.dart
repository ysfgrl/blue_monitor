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
  const LocalExitEvt();
  @override
  List<Object?> get props => [];
}