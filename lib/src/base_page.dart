import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/bloc/env/env_list_bloc.dart';


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
          return Center(
            child: CircularProgressIndicator(),
          );
          
        }
        return child;
      },
      
    );
  }

}
