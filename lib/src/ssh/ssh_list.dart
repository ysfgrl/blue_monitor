import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_connection_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/ssh_list_bloc.dart';
import 'package:serial_monitor/src/helper/dialog.dart';
import 'package:serial_monitor/src/ssh/ssh_list_item.dart';

import 'ssh_connection_dialog.dart';

class SshListTab extends StatelessWidget {
  const SshListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: BlocBuilder<SshListBloc, SshListState>(
          builder: (context, state) {
            if (state.status == SshListStatus.init) {
              context.read<SshListBloc>().add(const SshLoadListEvent());
            }
            final isBusy = state.status == SshListStatus.init || state.status == SshListStatus.loading;
            if(isBusy){
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            if(state.connections.isEmpty){
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        context.tr('ssh.savedConnections'),
                        style: theme.textTheme.titleLarge,
                      ),
                      Tooltip(
                        message: context.tr('ssh.newConnection'),
                        child: FilledButton.tonalIcon(
                          onPressed: isBusy
                              ? null
                              : () async {
                            final saved = await SshConnectionDialog.show(
                                context,
                                store: state.store
                            );
                            if (saved == true) {
                              context.read<SshListBloc>().add(const SshLoadListEvent());
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(context.tr('ssh.newConnection')),
                        ),
                      ),
                    ],
                  ),
                  if (isBusy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.error!.tr(context: context),
                      style: TextStyle(color: colors.error),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => context.read<SshListBloc>().add(const SshLoadListEvent()),
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('global.retry')),
                      ),
                    ),
                  ],
                  if (!isBusy &&
                      state.error == null &&
                      state.connections.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.tr('ssh.noSavedConnections'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: state.connections.length,
              itemBuilder: (context, index) {
                final bloc = state.connections[index];
                return SshListItem(
                    bloc: bloc,
                    delete: () async{
                      try {
                        final confirmed = await context.blueDialog<bool>(
                          title: Text(context.tr('setting.deleteEnvironment')),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.tr(
                                    'setting.deleteEnvironmentConfirmation',
                                    namedArgs: {'name': bloc.state.connection.name},
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context, rootNavigator: true).pop(false),
                                      child: Text(context.tr('global.cancel')),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                        foregroundColor: Theme.of(context).colorScheme.onError,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context, rootNavigator: true).pop(true),
                                      child: Text(context.tr('global.delete')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                        if (confirmed != true) return;
                        await state.store.delete(bloc.state.connection.id);
                        if (!bloc.isClosed) context.read<SshListBloc>().add(const SshLoadListEvent());
                      } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('setting.deleteFailed'))),
                          );

                      }
                    },
                    edit: () async{
                      final saved = await SshConnectionDialog.show(
                          context,
                          store: state.store,
                        connection: bloc.state.connection
                      );
                      if (saved == true) {
                        context.read<SshListBloc>().add(const SshLoadListEvent());
                      }
                    },
                );
              },
            );
          },
        ),
      ),
    );
  }

}
