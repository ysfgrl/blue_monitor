import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:serial_monitor/src/bloc/env/store.dart';
import 'package:serial_monitor/src/helper/dialog.dart';

import '../bloc/env/env_model.dart';
import '../bloc/env/env_type.dart';

class EnvironmentDialog extends StatefulWidget {
  const EnvironmentDialog({super.key, this.environment});

  final EnvModel? environment;

  static Future<bool?> show(BuildContext context, {EnvModel? environment}) {
    return context.blueDialog<bool>(
      title: Text(
        context.tr(
          environment == null
              ? 'setting.newEnvironment'
              : 'setting.editEnvironment',
        ),
      ),
      icon: Icon(environment == null ? Icons.add_rounded : Icons.edit_outlined),
      child: EnvironmentDialog(environment: environment),
    );
  }

  @override
  State<EnvironmentDialog> createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<EnvironmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final String _id;
  late EnvironmentType _type;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final environment = widget.environment;
    _name = TextEditingController(text: environment?.name ?? '');
    _url = TextEditingController(text: environment?.url ?? '');
    _id =
        environment?.id ??
        'env-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    _type = environment?.type ?? EnvironmentType.local;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final environment = EnvModel(
        id: _id,
        name: _name.text.trim(),
        type: _type,
        url: _type == EnvironmentType.claude ? _url.text.trim() : null,
      );
      final error = widget.environment == null
          ? await envStore.add(environment)
          : await envStore.update(environment);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = error;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'setting.saveFailed';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
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
                validator: (value) => EnvModel.isValidUrl(value?.trim() ?? '')
                    ? null
                    : context.tr('setting.invalidUrl'),
                onFieldSubmitted: (_) => _save(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(context.tr('global.cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.tr(
                            widget.environment == null
                                ? 'global.save'
                                : 'global.update',
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
