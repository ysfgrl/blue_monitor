

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';
import 'package:serial_monitor/src/bloc/env/env_model.dart';

class EnvListSelectDrop extends StatelessWidget{
  const EnvListSelectDrop({super.key});


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnvListBloc, EnvListState>(
      builder: (context, state) {
        if(state.environments.isEmpty){
          return DropdownButtonFormField<EnvModel>(
            key: ValueKey(('environment', state.selected, state.status)),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'setting.environment'.tr(),
              prefixIcon: const Icon(Icons.layers_outlined),
            ),
            onChanged: (value) {

            },
            items: [
            ],
          );
        }
        return DropdownButtonFormField<EnvModel>(
          key: ValueKey(('environment', state.selected, state.status)),
          initialValue: state.selected?.model,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'setting.environment'.tr(),
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
}