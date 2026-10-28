import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:serial_monitor/src/base_page.dart';

import 'home_screen.dart';
import 'local/local_terminal.dart';
import 'serial/serial_terminal.dart';
import 'setting/setting.dart';
import 'ssh/ssh_terminal.dart';

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return BasePage(child: child,);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/serial',
          builder: (context, state) => const SerialTerminal(),
        ),
        GoRoute(
          path: '/local',
          builder: (context, state) => const LocalTerminal(),
        ),
        GoRoute(
          path: '/ssh',
          builder: (context, state) => const SshTerminal(),
        ),
        GoRoute(
          path: '/setting',
          builder: (context, state) => const Setting(),
        ),
      ]
    ),
  ],
);
