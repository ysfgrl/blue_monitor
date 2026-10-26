import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_screen.dart';
import 'local/local_terminal.dart';
import 'serial/serial_terminal.dart';
import 'ssh/ssh_terminal.dart';

final appRouter = GoRouter(
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => PopScope(
        canPop: shell.currentIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && shell.currentIndex != 0) context.go('/');
        },
        child: shell,
      ),
      // Keep terminal subscriptions and scrollback alive while visiting home.
      navigatorContainerBuilder: (context, shell, children) => IndexedStack(
        index: shell.currentIndex,
        children: [
          for (var index = 0; index < children.length; index++)
            Offstage(
              offstage: index != shell.currentIndex,
              child: TickerMode(
                enabled: index == shell.currentIndex,
                child: ExcludeFocus(
                  excluding: index != shell.currentIndex,
                  child: children[index],
                ),
              ),
            ),
        ],
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/serial',
              builder: (context, state) => const SerialTerminal(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/local',
              builder: (context, state) => const LocalTerminal(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/ssh',
              builder: (context, state) => const SshTerminal(),
            ),
          ],
        ),
      ],
    ),
  ],
);
