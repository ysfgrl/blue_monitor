import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/env_bloc/store.dart';

import '../bloc/env_bloc/env_bloc.dart';
import '../bloc/env_bloc/env_model.dart';
import '../bloc/env_bloc/env_type.dart';

class EnvironmentDialog extends StatefulWidget {
  const EnvironmentDialog({super.key});

  @override
  State<EnvironmentDialog> createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<EnvironmentDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _id = 'env-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  EnvironmentType _type = EnvironmentType.local;
  bool _saving = false;

  void _save() async {
    final state = context.read<EnvBloc>().state;
    if (_saving ||
        state.status == EnvStatus.loading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    var res = await envStore.add(EnvModel(
      id: _id,
      name: _name.text.trim(),
      type: _type,
      url: _type == EnvironmentType.claude ? _url.text.trim() : null,
    ),
    );
    if(res != null){
      //burada
      return;
    }
    context.read<EnvBloc>().add(EnvReadList());
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<EnvBloc, EnvState>(
    listener: (context, state) {
      if (!_saving || state.status == EnvStatus.loading) return;
      if (state.status == EnvStatus.loaded &&
          state.environments.any((env) => env.id == _id)) {
        Navigator.of(context).pop();
      } else if (state.status == EnvStatus.error) {
        setState(() => _saving = false);
      }
    },
    builder: (context, state) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(context.tr('setting.newEnvironment')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('setting.environmentName'),
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) {
                        return context.tr('setting.environmentNameRequired');
                      }
                      if (state.environments.any(
                        (item) => item.name.toLowerCase() == name.toLowerCase(),
                      )) {
                        return context.tr('setting.environmentNameExists');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EnvironmentType>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: context.tr('setting.environmentType'),
                    ),
                    items: [
                      for (final type in EnvironmentType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(context.tr('setting.${type.name}Type')),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (type) {
                            if (type != null) setState(() => _type = type);
                          },
                  ),
                  if (_type == EnvironmentType.claude) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _url,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: context.tr('setting.claudeUrl'),
                        hintText: context.tr('setting.urlHint'),
                        errorMaxLines: 3,
                      ),
                      validator: (value) =>
                          EnvModel.isValidUrl(value?.trim() ?? '')
                          ? null
                          : context.tr('setting.invalidUrl'),
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.tr(state.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('global.cancel')),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('global.save')),
          ),
        ],
      ),
    ),
  );
}
