import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';
import 'package:serial_monitor/src/env/environment_dialog.dart';
import 'package:serial_monitor/src/env/list_select_drop.dart';


class BasePage extends StatelessWidget {
  final Widget child;
  const BasePage({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnvListBloc, EnvListState>(

      builder: (context, state) {
        if(state.status == EnvListStatus.init){
          context.read<EnvListBloc>().add(EnvListReadList());
        }
        if(state.status != EnvListStatus.loaded){
          return Scaffold(
            appBar: AppBar(
              title: Text('global.appName'.tr()),
              actions: [
                IconButton(
                  tooltip: 'setting.title'.tr(),
                  onPressed: () => context.go('/setting'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );

        }
        if (state.environments.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text('global.appName'.tr()),
              actions: [
                IconButton(
                  tooltip: 'setting.title'.tr(),
                  onPressed: () => context.go('/setting'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            body: Center(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Create Environment"),
                    FilledButton.icon(
                      onPressed:  () async{
                        var res = await EnvironmentDialog.show(context);
                        if(res == null) return;
                        if(res == true){
                          context.read<EnvListBloc>().add(EnvListReadList());
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('setting.createEnvironment')),
                    )
                  ],
                ),
              ),
            ),
          );
        }
        if(state.selected == null){
          return Scaffold(
            appBar: AppBar(
              title: Text('global.appName'.tr()),
              actions: [
                IconButton(
                  tooltip: 'setting.title'.tr(),
                  onPressed: () => context.go('/setting'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            body: Center(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Select Environment"),
                    EnvListSelectDrop()
                  ],
                ),
              ),
            ),
          );
        }
        return child;
      },

    );
  }

}
