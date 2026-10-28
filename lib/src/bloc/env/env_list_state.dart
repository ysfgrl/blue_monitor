part of 'env_list_bloc.dart';

enum EnvListStatus { init, loading, loaded, error }

class EnvState extends Equatable{
  final EnvModel model;
  final SshListBloc ssh;
  const EnvState(this.model, this.ssh);
  @override
  List<Object?> get props => [model, ssh];
}

class EnvListState extends Equatable {
  const EnvListState({
    this.status = EnvListStatus.init,
    this.environments = const [],
    this.selected,
    this.error,
  });

  final EnvListStatus status;
  final List<EnvState> environments;
  final EnvState? selected;
  final String? error;

  EnvListState copyWith({
    EnvListStatus? status,
    List<EnvState>? environments,
    EnvState? selected,
    String? error,
  }) => EnvListState(
    status: status ?? this.status,
    environments: environments ?? this.environments,
    selected: selected ?? this.selected,
    error: error,
  );

  @override
  List<Object?> get props => [status, environments, selected, error];
}
