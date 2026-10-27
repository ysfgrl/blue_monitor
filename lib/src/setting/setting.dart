import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/env_bloc/env_bloc.dart';
import '../bloc/env_bloc/env_model.dart';
import '../extensions/flag.dart';
import 'environment_dialog.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => context.go('/')),
      title: Text(context.tr('setting.title')),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.tr('setting.applicationLanguage'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Locale>(
                initialValue: context.locale,
                decoration: InputDecoration(
                  labelText: context.tr('setting.language'),
                  prefixIcon: const Icon(Icons.language),
                ),
                items: [
                  for (final locale in context.supportedLocales)
                    DropdownMenuItem(
                      value: locale,
                      child: Text('${locale.flag()} ${locale.name()}'),
                    ),
                ],
                onChanged:  (value) {
                  if(value == null) return;
                  context.setLocale(value);
                },
              ),
              const SizedBox(height: 32),
              _environmentSection(context),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _environmentSection(
    BuildContext context,
  ) => BlocBuilder<EnvBloc, EnvState>(
    builder: (context, state) {
      final bloc = context.read<EnvBloc>();
      final enabled =
          state.status != EnvStatus.init && state.status != EnvStatus.loading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == EnvStatus.loading)
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
                  if (state.status == EnvStatus.error)
                    TextButton.icon(
                      onPressed: () => bloc.add(const EnvReadList()),
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
                onPressed: enabled
                    ? () => showDialog<void>(
                        context: context,
                        useRootNavigator: false,
                        barrierDismissible: false,
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: const EnvironmentDialog(),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.add),
                label: Text(context.tr('setting.addEnvironment')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.tr('setting.selectEnvironment')),
          const SizedBox(height: 12),
          RadioGroup<EnvModel>(
            groupValue: state.selected,
            onChanged: (env) {
              if (enabled && env != null) {
                bloc.add(EnvSelect(env));
              }
            },
            child: Column(
              children: [
                for (final environment in state.environments)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<EnvModel>(
                      value: environment,
                      enabled: enabled,
                      title: Text(environment.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('setting.${environment.type.name}Type'),
                          ),
                          if (environment.url != null) Text(environment.url!),
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
