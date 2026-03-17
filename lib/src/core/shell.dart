import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'shell_config.dart';

/// Boots the Soliplex shell from a [ShellConfig].
///
/// Validates routes before calling [runApp]. Throws [ArgumentError] if the
/// route configuration is invalid (e.g. duplicate paths).
///
/// Uses [UniqueKey] so that hot restart (which re-runs main) creates a fresh
/// widget tree. Hot reload does not re-run main, so this is safe.
void runSoliplexShell(ShellConfig config) {
  final errors = validateRoutes(
    routes: config.routes,
    initialRoute: config.initialRoute,
  );
  if (errors.isNotEmpty) {
    throw ArgumentError('Invalid route configuration:\n${errors.join('\n')}');
  }

  runApp(SoliplexShell(key: UniqueKey(), config: config));
}

class SoliplexShell extends StatelessWidget {
  final ShellConfig config;

  const SoliplexShell({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: config.overrides,
      child: MaterialApp.router(
        title: config.appName,
        theme: config.theme,
        routerConfig: buildRouter(config),
      ),
    );
  }
}
