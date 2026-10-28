import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:serial_monitor/src/bloc/env/store.dart';
import 'package:serial_monitor/src/helper/dialog.dart';

import '../bloc/env/env_model.dart';
import '../bloc/env/env_type.dart';

class EnvironmentDialog extends StatefulWidget {
  const EnvironmentDialog({super.key});

  static Future<bool?> show(BuildContext context){
    return context.blueDialog<bool>(
        title: Text('setting.newEnvironment'.tr()),
        child: EnvironmentDialog( )
    );
  }
  @override
  State<EnvironmentDialog> createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<EnvironmentDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _id = 'env-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  EnvironmentType _type = EnvironmentType.local;
  bool _saving = false;
  String? error;

  void _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    var res = await envStore.add(EnvModel(
        id: _id,
        name: _name.text.trim(),
        type: _type,
        url: _type == EnvironmentType.claude ? _url.text.trim() : null,
      ));
    if(res != null){
      Navigator.of(context).pop(true);
      return;
    }
    error = "global.save_error";
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return SingleChildScrollView(
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
            onChanged: _saving ? null : (type) {
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
          if(error!=null)
            Text(error!.tr()),
          SizedBox(height: 16,),
          Row(
            children: [
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
          )
        ],
      ),
    );
  }
}
