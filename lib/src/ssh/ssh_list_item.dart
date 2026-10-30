import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/ssh/connection/ssh_connection_bloc.dart';
import 'package:serial_monitor/src/ssh/ssh_host_key_listener.dart';

class SshListItem extends StatefulWidget {
  const SshListItem({super.key, required this.bloc, required this.delete, required this.edit});

  final SshConnectionBloc bloc;
  final VoidCallback delete;
  final VoidCallback edit;

  @override
  State<SshListItem> createState() => _SshListItemState();
}

class _SshListItemState extends State<SshListItem> {
  bool _askingHostKey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStateChanged(context, widget.bloc.state);
    });
  }

  Future<void> _onStateChanged(BuildContext context, SshConnectionState state,) async {
    if (state.status != SshStatus.challenge || _askingHostKey) return;
    final bloc = widget.bloc;
    final challenge = state.hostKeyChallenge;
    _askingHostKey = true;
    try {
      final trusted = await SshHostKeyAskWidget.show(context, state) ?? false;
      if (bloc.isClosed || (mounted && !identical(widget.bloc, bloc))) return;
      if (bloc.state.status == SshStatus.challenge && identical(bloc.state.hostKeyChallenge, challenge)) {
        bloc.add(SshHostKeyAnswered(trusted));
      }
    } finally {
      _askingHostKey = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = widget.bloc;
    return BlocConsumer<SshConnectionBloc, SshConnectionState>(
      bloc: bloc,
      listener: _onStateChanged,
      listenWhen: (previous, current) => current.status == SshStatus.challenge && (previous.status != current.status || previous.hostKeyChallenge != current.hostKeyChallenge),
      builder: (context, state) {
        final colors = Theme.of(context).colorScheme;
        final busy = state.isConnecting || state.isOpeningSession;
        final canModify = !busy && !state.isConnected;
        final actions = [
          if (busy)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: context.tr('global.connecting'))),
            ),
          if (!state.isConnecting)
            IconButton(
              tooltip: context.tr(state.isConnected ? 'ssh.newSession' : state.hasError ? 'global.retry' : 'global.connect'),
              onPressed: busy || bloc.isClosed ? null : () => bloc.add(state.isConnected ? const SshNewSessionEvt() : const SshConnectRequested()),
              style: IconButton.styleFrom(foregroundColor: colors.primary),
              icon: Icon(state.isConnected ? Icons.add_rounded : Icons.play_arrow_rounded, size: 20),
            ),
          if (state.isConnected || state.isConnecting)
            IconButton(
              tooltip: context.tr(state.isConnecting ? 'global.cancelConnection' : 'global.disconnect'),
              onPressed: bloc.isClosed ? null : () => bloc.add(const SshDisconnectRequested()),
              icon: const Icon(Icons.link_off_rounded, size: 20),
            ),
          IconButton(
            tooltip: context.tr('global.edit'),
            onPressed: canModify && !bloc.isClosed ? widget.edit : null,
            style: IconButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: context.tr('ssh.deleteConnection'),
            onPressed: canModify && !bloc.isClosed ? widget.delete : null,
            style: IconButton.styleFrom(foregroundColor: colors.error),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ];
        final details = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: canModify && !bloc.isClosed ? () => bloc.add(const SshConnectRequested()) : null,
          title: Text(state.connection.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(state.connection.destination, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.onSurfaceVariant)),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: state.isConnected ? colors.primary.withValues(alpha: .08) : colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: state.isConnected ? colors.primary.withValues(alpha: .5) : colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 440
                      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, Wrap(alignment: WrapAlignment.end, children: actions)])
                      : Row(children: [Expanded(child: details), ...actions, const SizedBox(width: 8)]),
                ),
                if (state.message != null && state.message!.isNotEmpty)
                  _errorBanner(context, state.message!, () => bloc.add(const SshErrorDismissed())),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _errorBanner(BuildContext context, String message, VoidCallback onDismiss,) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 2, bottom: 2),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: .35))),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 96), child: SingleChildScrollView(child: Text(message, style: TextStyle(color: color, fontSize: 13))))),
          IconButton(tooltip: context.tr('global.dismissNotification'), onPressed: onDismiss, icon: const Icon(Icons.close_rounded, size: 18)),
        ],
      ),
    );
  }
}
