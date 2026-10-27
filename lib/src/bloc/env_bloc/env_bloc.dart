import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'env_model.dart';
import 'store.dart';

part 'env_event.dart';
part 'env_state.dart';

class EnvBloc extends Bloc<EnvEvent, EnvState> {
  EnvBloc() : super(const EnvState()) {
    on<EnvEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  Future<void> _onEvent(EnvEvent event, Emitter<EnvState> emit) async {
    switch (event) {
      case EnvReadList():
        emit(state.copyWith(status: EnvStatus.loading));
        try {
          final environments = await envStore.list();
          final selectedId = await envStore.getSelected();
          final selected = environments.where((env) => env.id == selectedId).firstOrNull ??
              environments.firstOrNull;
          if (selected != null && selected.id != selectedId) {
            await envStore.select(selected);
          }
          if (!emit.isDone) {
            emit(
              EnvState(
                status: EnvStatus.loaded,
                environments: environments,
                selected: selected,
              ),
            );
          }
        } catch (_) {
          if (!emit.isDone) {
            emit(
              state.copyWith(
                status: EnvStatus.error,
                error: 'setting.loadFailed',
              ),
            );
          }
        }
      case EnvSelect(:final env):
        final selected = state.environments
            .where((item) => item.id == env.id)
            .firstOrNull;
        if (selected == null) return;
        emit(state.copyWith(status: EnvStatus.loading));
        try {
          await envStore.select(selected);
          if (!emit.isDone) {
            emit(state.copyWith(status: EnvStatus.loaded, selected: selected));
          }
        } catch (_) {
          if (!emit.isDone) {
            emit(
              state.copyWith(
                status: EnvStatus.error,
                error: 'setting.saveFailed',
              ),
            );
          }
        }
    }
  }
}
