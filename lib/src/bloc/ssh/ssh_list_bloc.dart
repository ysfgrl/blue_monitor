import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'store.dart';
import 'connection/ssh_connection_bloc.dart';
part 'ssh_list_event.dart';
part 'ssh_list_state.dart';

class SshListBloc extends Bloc<SshListEvent, SshListState> {
  SshListBloc({required SshConnectionStore store}) : super(SshListState(store: store)) {
    on<SshLoadListEvent>(_loadList);
  }

  bool _loading = false;
  bool _closing = false;

  Future<void> _loadList(SshLoadListEvent event, Emitter<SshListState> emit,) async {
    if (_loading || _closing) return;
    _loading = true;
    emit(state.copyWith(status: state.connections.isEmpty ? SshListStatus.loading : SshListStatus.loaded));
    final created = <SshConnectionBloc>[];
    try {
      final connections = await state.store.load();
      if (_closing || emit.isDone) return;
      final blocs = <SshConnectionBloc>[];
      for (final connection in connections) {
        final existing = state.connections.where((bloc) => !bloc.isClosed && bloc.state.connection == connection).firstOrNull;
        if (existing != null) {
          blocs.add(existing);
        } else {
          final bloc = SshConnectionBloc(connection: connection);
          created.add(bloc);
          blocs.add(bloc);
        }
      }
      final removed = state.connections.where((bloc) => !blocs.contains(bloc)).toList();
      emit(state.copyWith(status: SshListStatus.loaded, connections: List.unmodifiable(blocs)));
      for (final bloc in removed) {
        await bloc.close();
      }
    } catch (_) {
      for (final bloc in created) {
        if (!state.connections.contains(bloc)) await bloc.close();
      }
      if (!_closing && !emit.isDone) emit(state.copyWith(status: SshListStatus.error, error: 'ssh.storageFailed'));
    } finally {
      _loading = false;
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    for (final connection in state.connections) {
      await connection.close();
    }
    await super.close();
  }
}
