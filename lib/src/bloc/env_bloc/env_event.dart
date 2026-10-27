part of 'env_bloc.dart';

sealed class EnvEvent extends Equatable {
  const EnvEvent();
}

class EnvReadList extends EnvEvent {
  const EnvReadList();
  @override
  List<Object?> get props => [];
}

class EnvSelect extends EnvEvent {
  final EnvModel env;
  const EnvSelect(this.env);
  @override
  List<Object?> get props => [env];
}
