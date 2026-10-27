part of 'ssh_list_bloc.dart';

enum SshListStatus{
  init,
  loading,
  loaded,
  error
}
class SshListState extends Equatable {
  const SshListState({
    this.status = SshListStatus.init,
    this.connections = const [],
    this.error,
  });
  final SshListStatus status;
  final List<SshConnectionBloc> connections;
  final String? error;

  @override
  List<Object?> get props => [
    status,
    connections,
    error,
  ];

  SshListState copyWith({
    SshListStatus? status,
    List<SshConnectionBloc>? connections,
    String? error,
  }) => SshListState(
    connections: connections ?? this.connections,
    status: status ?? this.status,
    error: error ,
  );
}
