import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ssh_bloc/ssh_bloc.dart';
import '../models/ssh_connection.dart';
import '../term/terminal_panel.dart';
import 'ssh_host_key_listener.dart';

class SshSessionTab extends StatelessWidget {
  const SshSessionTab({
    super.key,
    required this.connection,
    required this.active,
    required this.onShowConnections,
  });

  final SshConnection connection;
  final bool active;
  final VoidCallback onShowConnections;

  @override
  Widget build(BuildContext context) => BlocProvider<SshBloc>(
    lazy: false,
    create: (_) => SshBloc()..add(SshConnectRequested(connection)),
    child: SshHostKeyListener(
      active: active,
      child: BlocBuilder<SshBloc, SshState>(
        builder: (context, state) {
          final bloc = context.read<SshBloc>();
          final output = state.output;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        connection.destination,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.isConnected || state.isConnecting)
                      IconButton(
                        tooltip: state.isConnecting
                            ? context.tr('global.cancelConnection')
                            : context.tr('global.disconnect'),
                        onPressed: () =>
                            bloc.add(const SshDisconnectRequested()),
                        icon: const Icon(Icons.link_off_rounded),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: output == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: state.isConnecting
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(context.tr('global.connecting')),
                                  ],
                                )
                              : Text(
                                  state.message ??
                                      context.tr('ssh.waitingForConnection'),
                                  textAlign: TextAlign.center,
                                  style: state.hasError
                                      ? TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        )
                                      : null,
                                ),
                        ),
                      )
                    : TerminalPanel(
                        key: ObjectKey(output),
                        incoming: output,
                        onOutput: bloc.send,
                        onResize: bloc.resize,
                        isConnected: true,
                        active: active && state.isConnected,
                        allowBackgroundOutput: true,
                      ),
              ),
              if (!state.isConnected && !state.isConnecting)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: output == null
                            ? const SizedBox.shrink()
                            : Text(
                                state.message ?? '',
                                style: state.hasError
                                    ? TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      )
                                    : null,
                              ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onShowConnections,
                        icon: const Icon(Icons.list_rounded),
                        label: Text(context.tr('ssh.savedConnections')),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
