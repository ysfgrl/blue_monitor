import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';
import 'package:serial_monitor/src/bloc/env/store.dart';
import 'package:serial_monitor/src/env/environment_dialog.dart';
import 'package:serial_monitor/src/helper/dialog.dart';

import '../bloc/env/env_model.dart';

class EnvironmentListWidget extends StatefulWidget {
  const EnvironmentListWidget({super.key});

  @override
  State<EnvironmentListWidget> createState() => _EnvironmentListWidgetState();
}

class _EnvironmentListWidgetState extends State<EnvironmentListWidget> {
  bool _busy = false;

  Future<void> _edit({EnvModel? environment}) async {
    final bloc = context.read<EnvListBloc>();
    setState(() => _busy = true);
    try {
      final saved = await EnvironmentDialog.show(
        context,
        environment: environment,
      );
      if (saved == true && !bloc.isClosed) {
        bloc.add(const EnvListReadList());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(EnvModel environment) async {
    final bloc = context.read<EnvListBloc>();
    setState(() => _busy = true);
    try {
      final confirmed = await context.blueDialog<bool>(
        title: Text(context.tr('setting.deleteEnvironment')),
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr(
                  'setting.deleteEnvironmentConfirmation',
                  namedArgs: {'name': environment.name},
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(false),
                    child: Text(context.tr('global.cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(true),
                    child: Text(context.tr('global.delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await envStore.delete(environment);
      if (!bloc.isClosed) bloc.add(const EnvListReadList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('setting.deleteFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return BlocBuilder<EnvListBloc, EnvListState>(
      builder: (context, state) {
        final bloc = context.read<EnvListBloc>();
        final enabled =
            !_busy &&
            state.status != EnvListStatus.init &&
            state.status != EnvListStatus.loading;
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
                      style: TextStyle(color: colors.error),
                    ),
                    if (state.status == EnvListStatus.error)
                      TextButton.icon(
                        onPressed: () => bloc.add(const EnvListReadList()),
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('global.retry')),
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
                  style: theme.textTheme.titleLarge,
                ),
                FilledButton.tonalIcon(
                  onPressed: enabled ? () => _edit() : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr('setting.addEnvironment')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('setting.selectEnvironment'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            RadioGroup<EnvModel>(
              groupValue: state.selected?.model,
              onChanged: (env) {
                if (enabled && env != null) bloc.add(EnvListSelect(env));
              },
              child: Column(
                children: [
                  for (final environment in state.environments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: state.selected?.model.id == environment.model.id
                            ? colors.primary.withValues(alpha: .08)
                            : colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                state.selected?.model.id == environment.model.id
                                ? colors.primary.withValues(alpha: .5)
                                : colors.outlineVariant,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<EnvModel>(
                                value: environment.model,
                                enabled: enabled,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                title: Text(environment.model.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr(
                                        'setting.${environment.model.type.name}Type',
                                      ),
                                    ),
                                    if (environment.model.url != null)
                                      Text(
                                        environment.model.url!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.tr('global.edit'),
                              onPressed: enabled
                                  ? () => _edit(environment: environment.model)
                                  : null,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: context.tr('global.delete'),
                              onPressed: enabled
                                  ? () => _delete(environment.model)
                                  : null,
                              style: IconButton.styleFrom(
                                foregroundColor: colors.error,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
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
