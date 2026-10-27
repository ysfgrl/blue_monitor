part of 'ssh_list_bloc.dart';

sealed class SshListEvent extends Equatable {
  const SshListEvent();

}

final class SshLoadListEvent extends SshListEvent {
  const SshLoadListEvent();
  @override
  List<Object?> get props => [];
}
