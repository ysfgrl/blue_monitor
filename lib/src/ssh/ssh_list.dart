import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_connection_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/ssh_list_bloc.dart';

import 'ssh_connection_dialog.dart';

class SshListTab extends StatelessWidget {
  const SshListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return BlocBuilder<SshListBloc, SshListState>(
      builder: (context, state) {
        final bloc = context.read<SshListBloc>();
        if (state.status == SshListStatus.init) {
          bloc.add(const SshLoadListEvent());
        }
        final isBusy =
            state.status == SshListStatus.init ||
            state.status == SshListStatus.loading;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: state.connections.length + 1,
              itemBuilder: (context, index) {
                if (index > 0) {
                  return _connectionBuilder(
                    state.connections[index - 1],
                    enabled: !isBusy,
                  );
                }
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
                                    if (saved == true && !bloc.isClosed) {
                                      bloc.add(const SshLoadListEvent());
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
                              : () => bloc.add(const SshLoadListEvent()),
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
              },
            ),
          ),
        );
      },
    );
  }

  Widget _connectionBuilder(SshConnectionBloc bloc, {required bool enabled}) {
    return BlocBuilder<SshConnectionBloc, SshConnectionState>(
      bloc: bloc,
      builder: (context, state) {
        final colors = Theme.of(context).colorScheme;
        final connection = state.connection;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: state.isConnected
                ? colors.primary.withValues(alpha: .08)
                : colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: state.isConnected
                    ? colors.primary.withValues(alpha: .5)
                    : colors.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    enabled: enabled,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      connection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      connection.destination,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    onTap: enabled ? () {} : null,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('global.connect'),
                  onPressed: enabled ? () {} : null,
                  style: IconButton.styleFrom(foregroundColor: colors.primary),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                ),
                IconButton(
                  tooltip: context.tr('global.edit'),
                  onPressed: enabled ? () {} : null,
                  style: IconButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: context.tr('ssh.deleteConnection'),
                  onPressed: enabled ? () {} : null,
                  style: IconButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
