import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_connection_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_session.dart';
import 'package:serial_monitor/src/bloc/ssh/ssh_list_bloc.dart';
import '../term/terminal_panel.dart';

class SshSessionListTab extends StatelessWidget {
  const SshSessionListTab({
    super.key,
  });
  @override
  Widget build(BuildContext context){
    return BlocBuilder<SshListBloc, SshListState>(
      builder: (context, state) {
          if(state.status == SshListStatus.init){
            context.read<SshListBloc>().add(SshLoadListEvent());
          }
          final isBusy = state.status != SshListStatus.loaded;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr('ssh.savedConnections'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if(isBusy)
                     const LinearProgressIndicator(),
                    if (state.error != null) ...[
                      Text(
                        state.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      TextButton(
                        onPressed: isBusy
                            ? null
                            : (){
                          // _bloc.add(const SshConnectionsRequested())
                        },
                        child: Text(context.tr('ssh.reloadConnections')),
                      ),
                    ],
                    Expanded(
                      child: isBusy && state.connections.isEmpty
                          ? Center(child: Text(context.tr('ssh.noSavedConnections')))
                          : ListView.builder(
                        itemCount: state.connections.length,
                        itemBuilder: (context, index) => _connectionBuilder(state.connections[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      },
    );
  }

  Widget _connectionBuilder(SshConnectionBloc bloc){
    return BlocBuilder<SshConnectionBloc, SshConnectionState>(
      bloc: bloc,
      builder: (context, state) {
        final connection = state.connection;
        return Card(
          child: ListTile(
            title: Text(
              connection.name,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              connection.destination,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: (){

            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.tr('global.connect'),
                  onPressed: () {

                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: context.tr('global.edit'),
                  onPressed:(){

                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: context.tr('ssh.deleteConnection'),
                  onPressed: (){

                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
