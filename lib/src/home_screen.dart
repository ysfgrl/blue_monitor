import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';

import 'bloc/env/env_model.dart';
import 'env/environment_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('global.appName')),
        actions: [
          IconButton(
            tooltip: context.tr('setting.title'),
            onPressed: () => context.go('/setting'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('global.terminal'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  _environmentSelector(context),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('local-terminal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => context.go('/local'),
                    icon: const Icon(Icons.terminal_rounded),
                    label: Text(context.tr('local.title')),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('ssh-terminal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => context.go('/ssh'),
                    icon: const Icon(Icons.dns_rounded),
                    label: Text(context.tr('ssh.title')),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('serial-terminal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => context.go('/serial'),
                    icon: const Icon(Icons.usb_rounded),
                    label: Text(context.tr('serial.title')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _environmentSelector(BuildContext context) => BlocConsumer<EnvListBloc, EnvListState>(
        listenWhen: (previous, current) => previous.error != current.error && current.error != null,
        listener: (context, state) {
          if (!TickerMode.valuesOf(context).enabled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!.tr(context: context))),
          );
        },
        builder: (context, state) {
          if (state.environments.isEmpty) {
            return FilledButton.icon(
              onPressed:  () async{
                 var res = await EnvironmentDialog.show(context);
                 if(res == null) return;
                 if(res == true){

                 }
              },
              icon: const Icon(Icons.add),
              label: Text(context.tr('setting.createEnvironment')),
            );
          }
          return DropdownButtonFormField<EnvModel>(
            key: ValueKey(('environment', state.selected, state.status)),
            initialValue: state.selected?.model,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'setting.environment'.tr(context: context),
              prefixIcon: const Icon(Icons.layers_outlined),
            ),
            onChanged:(env) {
              if (env != null && env != state.selected) {
                context.read<EnvListBloc>().add(EnvListSelect(env));
              }
            },
            items: [
              for (final environment in state.environments)
                DropdownMenuItem<EnvModel>(
                  value: environment.model,
                  child: Text(
                    environment.model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          );
        },
      );
}
