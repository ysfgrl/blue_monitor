import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ssh/connection/ssh_connection_bloc.dart';
import '../helper/dialog.dart';

class SshHostKeyListener extends StatelessWidget {
  final SshConnectionState state;
  const SshHostKeyListener({
    super.key,
    required this.state
  });
  static Future<bool?> show(BuildContext context, SshConnectionState state){
      return context.blueDialog<bool>(
          title: Text('ssh.trustServerTitle'.tr()),
          child: SshHostKeyListener(
            state: state,
          )
      );
  }

  @override
  Widget build(BuildContext context){

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
      'ssh.firstConnection'.tr( namedArgs: {
        'host': state.connection.host,
        'port': state.connection.port.toString(),
      },),
          ),
          const SizedBox(height: 12),
          Text(
            'ssh.keyType'.tr(namedArgs:  {'type': state.hostKeyChallenge?.type??""}),
          ),
          const SizedBox(height: 8),
          SelectableText(state.hostKeyChallenge?.fingerprint ?? ""),
          const SizedBox(height: 12),
          Text(context.tr('ssh.verifyFingerprint')),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('global.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.tr('ssh.trustAndConnect')),
              ),
            ],
          )
        ],
      ),
    );
  }
}