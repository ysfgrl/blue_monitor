part of 'env_bloc.dart';

enum EnvStatus { init, loading, loaded, error }

class EnvState extends Equatable {
  const EnvState({
    this.status = EnvStatus.init,
    this.environments = const [],
    this.selected,
    this.error,
  });

  final EnvStatus status;
  final List<EnvModel> environments;
  final EnvModel? selected;
  final String? error;

  EnvState copyWith({
    EnvStatus? status,
    List<EnvModel>? environments,
    EnvModel? selected,
    String? error,
  }) => EnvState(
    status: status ?? this.status,
    environments: environments ?? this.environments,
    selected: selected ?? this.selected,
    error: error,
  );

  @override
  List<Object?> get props => [status, environments, selected, error];
}
