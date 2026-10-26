import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/bloc/local_bloc/local_bloc.dart';
import 'src/bloc/serial_bloc/serial_bloc.dart';
import 'src/bloc/ssh_bloc/ssh_bloc.dart';
import 'src/router.dart';

void main() => runApp(
  MultiBlocProvider(
    providers: [
      BlocProvider<LocalBloc>(
        create: (_) => LocalBloc()..add(const LocalStarted()),
      ),
      BlocProvider<SshBloc>(
        lazy: false,
        create: (_) {
          final bloc = SshBloc();
          if (!kIsWeb) bloc.add(const SshConnectionsRequested());
          return bloc;
        },
      ),
      BlocProvider<SerialBloc>(
        lazy: false,
        create: (_) => SerialBloc()..add(const SerialPortsRefreshRequested()),
      ),
    ],
    child: const SerialMonitorApp(),
  ),
);

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
      title: 'Serial Terminal',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
