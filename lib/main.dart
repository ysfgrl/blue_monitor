import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/bloc/local_bloc/local_bloc.dart';
import 'src/bloc/env_bloc/env_bloc.dart';
import 'src/bloc/serial_bloc/serial_bloc.dart';
import 'src/router.dart';

class _TranslationAssetLoader extends RootBundleAssetLoader {
  const _TranslationAssetLoader();

  @override
  String getLocalePath(String basePath, Locale locale) =>
      '$basePath/$locale.json';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      path: 'assets/translations',
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      assetLoader: _TranslationAssetLoader(),
      saveLocale: true,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<EnvBloc>(
            lazy: false,
            create: (_) => EnvBloc()..add(const EnvReadList()),
          ),
          BlocProvider<LocalBloc>(create: (_) => LocalBloc()),
          BlocProvider<SerialBloc>(
            lazy: false,
            create: (_) =>
                SerialBloc()..add(const SerialPortsRefreshRequested()),
          ),
        ],
        child: const SerialMonitorApp(),
      ),
    ),
  );
}

class SerialMonitorApp extends StatelessWidget {
  const SerialMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5EE0B5),
      brightness: Brightness.dark,
      surface: const Color(0xFF131C28),
    );
    return MaterialApp.router(
      routerConfig: appRouter,
      onGenerateTitle: (context) => context.tr('global.appTitle'),
      debugShowCheckedModeBanner: false,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B111A),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B111A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        dividerColor: const Color(0xFF283343),
      ),
    );
  }
}
