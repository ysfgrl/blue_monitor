import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ssh/connection/ssh_connection_bloc.dart';

class SshHostKeyListener extends StatefulWidget {
  const SshHostKeyListener({
    super.key,
    required this.child,
    this.active = true,
  });

  final Widget child;
  final bool active;

  @override
  State<SshHostKeyListener> createState() => _SshHostKeyListenerState();
}

class _SshHostKeyListenerState extends State<SshHostKeyListener> {
  DialogRoute<bool>? _route;
  int? _challengeId;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant SshHostKeyListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _dismiss() {
    final route = _route;
    _route = null;
    _challengeId = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route, false);
    }
  }

  void _sync() {
    final bloc = context.read<SshConnectionBloc>();
    final challenge = bloc.state.hostKeyChallenge;
    if (!widget.active || challenge == null) {
      _dismiss();
      return;
    }
    if (_route != null && _challengeId != challenge.id) _dismiss();
    if (_route == null) unawaited(_show(bloc, challenge));
  }

  Future<void> _show(
    SshConnectionBloc bloc,
    SshHostKeyChallenge challenge,
  ) async {
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('ssh.trustServerTitle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  'ssh.firstConnection',
                  namedArgs: {
                    'host': challenge.host,
                    'port': challenge.port.toString(),
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('ssh.keyType', namedArgs: {'type': challenge.type}),
              ),
              const SizedBox(height: 8),
              SelectableText(challenge.fingerprint),
              const SizedBox(height: 12),
              Text(context.tr('ssh.verifyFingerprint')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('global.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('ssh.trustAndConnect')),
          ),
        ],
      ),
    );
    _route = route;
    _challengeId = challenge.id;
    final trusted = await Navigator.of(context).push(route) ?? false;
    // A hidden/closed tab dismisses the dialog without answering another tab.
    if (!mounted || !identical(_route, route)) return;
    _route = null;
    _challengeId = null;
    if (!bloc.isClosed && bloc.state.hostKeyChallenge?.id == challenge.id) {
      bloc.add(SshHostKeyAnswered(challenge.id, trusted: trusted));
    }
  }

  @override
  void dispose() {
    final route = _route;
    _route = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route, false);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<SshConnectionBloc, SshConnectionState>(
        listenWhen: (previous, current) =>
            previous.hostKeyChallenge != current.hostKeyChallenge,
        listener: (_, state) => _scheduleSync(),
        child: widget.child,
      );
}
