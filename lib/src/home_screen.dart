import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Blue Monitor")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Terminal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('local-terminal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => context.go('/local'),
                    icon: const Icon(Icons.terminal_rounded),
                    label: const Text('Local terminal'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('ssh-terminal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => context.go('/ssh'),
                    icon: const Icon(Icons.dns_rounded),
                    label: const Text('SSH terminal'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('serial-terminal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => context.go('/serial'),
                    icon: const Icon(Icons.usb_rounded),
                    label: const Text('Serial terminal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
