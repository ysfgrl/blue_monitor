import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/env/env_model.dart';
import 'package:serial_monitor/src/bloc/env/store.dart';
import 'package:serial_monitor/src/bloc/ssh/ssh_list_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/store.dart';

part 'env_list_event.dart';
part 'env_list_state.dart';

class EnvListBloc extends Bloc<EnvListEvent, EnvListState> {
  EnvListBloc() : super(EnvListState()) {
    on<EnvListReadList>(_read);
    on<EnvListSelect>(_select);
  }

  Future<void> _read(EnvListEvent event, Emitter<EnvListState> emit) async {
    emit(state.copyWith(status: EnvListStatus.loading));
    try {
      final environments = await envStore.list();
      final selectedId = await envStore.getSelected();


      final List<EnvState> list =  environments.map((e) => EnvState(e, SshListBloc(
          store: SshConnectionStore(envId: e.id)
      )),).toList();

      final selected = list.where((env) => env.model.id == selectedId).firstOrNull ?? list.firstOrNull;

      if (!emit.isDone) {
        emit(EnvListState(
            status: EnvListStatus.loaded,
            environments: list,
            selected: selected,
          ),
        );
      }
    } catch (_) {
      if (!emit.isDone) {
        emit(
          state.copyWith(
            status: EnvListStatus.error,
            error: 'setting.loadFailed',
          ),
        );
      }
    }
  }
  Future<void> _select(EnvListSelect event, Emitter<EnvListState> emit) async {
    emit(state.copyWith(
      selected: state.environments.where((env) => env.model.id == event.env.id).firstOrNull
    ));

  }
}
