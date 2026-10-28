import 'package:dartssh2/dartssh2.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'store.dart';
import 'connection/ssh_connection_bloc.dart';
part 'ssh_list_event.dart';
part 'ssh_list_state.dart';

class SshListBloc extends Bloc<SshListEvent, SshListState> {
  SshListBloc({
    required this.store,
  }) : super(const SshListState()) {
    on<SshLoadListEvent>(_loadList);
  }
  final SshConnectionStore store;
  void _loadList(SshLoadListEvent event, Emitter<SshListState> emit) async{
    emit(state.copyWith(
      status: SshListStatus.loading
    ));

    var connections = await store.load();
    List<SshConnectionBloc> blocs = [];
    for(var connection in connections){
      blocs.add(SshConnectionBloc(
        connection: connection,
      ));
    }
    emit(state.copyWith(
        status: SshListStatus.loaded,
        connections: blocs
    ));
  }

  @override
  Future<void> close() async {
    for(var connection in state.connections){
      await connection.close();
    }
    super.close();
  }
}
