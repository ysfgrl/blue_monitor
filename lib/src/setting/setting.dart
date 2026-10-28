import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';
import 'package:serial_monitor/src/env/environment_list.dart';
import '../bloc/env/env_model.dart';
import '../extensions/flag.dart';
import '../env/environment_dialog.dart';

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
              EnvironmentListWidget()
            ],
          ),
        ),
      ),
    ),
  );

}
