import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';
import 'package:serial_monitor/src/bloc/env/store.dart';
import 'package:serial_monitor/src/env/environment_dialog.dart';
import 'package:serial_monitor/src/helper/dialog.dart';

import '../bloc/env/env_model.dart';
import '../bloc/env/env_type.dart';

class EnvironmentListWidget extends StatelessWidget {
  const EnvironmentListWidget({super.key});
@override
  Widget build(BuildContext context) {
  return BlocBuilder<EnvListBloc, EnvListState>(
    builder: (context, state) {
      final bloc = context.read<EnvListBloc>();
      final enabled = state.status != EnvListStatus.init && state.status != EnvListStatus.loading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == EnvListStatus.loading)
            const LinearProgressIndicator(),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.error!.tr(context: context),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (state.status == EnvListStatus.error)
                    TextButton.icon(
                      onPressed: () => bloc.add(const EnvListReadList()),
                      icon: const Icon(Icons.refresh),
                      label: Text('global.retry'.tr(context: context)),
                    ),
                ],
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                context.tr('setting.environment'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              FilledButton.tonalIcon(
                onPressed: enabled ? () async {
                  var res  = await EnvironmentDialog.show(context);
                  if(res == null) return;
                  if(res == true){
                    bloc.add(EnvListReadList());
                  }
                }: null,
                icon: const Icon(Icons.add),
                label: Text(context.tr('setting.addEnvironment')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.tr('setting.selectEnvironment')),
          const SizedBox(height: 12),
          RadioGroup<EnvModel>(
            groupValue: state.selected?.model,
            onChanged: (env) {
              if (enabled && env != null) {
                bloc.add(EnvListSelect(env));
              }
            },
            child: Column(
              children: [
                for (final environment in state.environments)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<EnvModel>(
                      value: environment.model,
                      enabled: enabled,
                      title: Text(environment.model.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('setting.${environment.model.type.name}Type'),
                          ),
                          if (environment.model.url != null) Text(environment.model.url!),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
  }
}
