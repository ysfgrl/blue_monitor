import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_connection_bloc.dart';
import 'package:serial_monitor/src/ssh/ssh_host_key_listener.dart';

class SshListItem extends StatelessWidget {
  final SshConnectionBloc bloc;
  final VoidCallback delete;
  final VoidCallback edit;
  const SshListItem({
    super.key,
    required this.bloc,
    required this.delete,
    required this.edit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SshConnectionBloc, SshConnectionState>(
      listener: (context, state) async{
        if(state.status == SshStatus.challenge){
          var res = await SshHostKeyAskWidget.show(context, state);
          if(res == true){
            bloc.add(SshHostKeyAnswered(true));
          }
        }

      },
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
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
                      ),
                    ),
                    if(state.status == SshStatus.idle)
                      IconButton(
                        tooltip: context.tr('global.connect'),
                        onPressed: () {
                          bloc.add(SshConnectRequested());
                        },
                        style: IconButton.styleFrom(foregroundColor: colors.primary),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      )
                    else if(state.status == SshStatus.connecting ||
                        state.status == SshStatus.challenge ||
                        state.status == SshStatus.password)
                      CircularProgressIndicator()
                    else if(state.status == SshStatus.connected)
                        IconButton(
                          tooltip: context.tr('global.connect'),
                          onPressed: () {
                            bloc.add(SshConnectRequested());
                          },
                          style: IconButton.styleFrom(foregroundColor: colors.primary),
                          icon: const Icon(Icons.plus_one, size: 20),
                        ),
                    IconButton(
                      tooltip: context.tr('global.edit'),
                      onPressed: edit,
                      style: IconButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    IconButton(
                      tooltip: context.tr('ssh.deleteConnection'),
                      onPressed: delete,
                      style: IconButton.styleFrom(foregroundColor: colors.error),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                if(state.status == SshStatus.failed)
                  _errorBanner(context, "${state.message}", () {

                  },)
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _errorBanner(
      BuildContext context,
      String message,
      VoidCallback onDismiss,
      ) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(2),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
