part of 'env_list_bloc.dart';

sealed class EnvListEvent extends Equatable {
  const EnvListEvent();
}

class EnvListReadList extends EnvListEvent {
  const EnvListReadList();
  @override
  List<Object?> get props => [];
}

class EnvListSelect extends EnvListEvent {
  final EnvModel env;
  const EnvListSelect(this.env);
  @override
  List<Object?> get props => [env];
}
