import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/shell_config.dart';
import '../interfaces/auth_state.dart';
import '../modules/auth/auth_module.dart';

ShellConfig standard({
  String appName = 'Soliplex',
  ThemeData? theme,
}) {
  return ShellConfig(
    appName: appName,
    theme: theme ?? ThemeData(),
    modules: [
      authModule(auth: const Unauthenticated()),
      ModuleContribution(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Soliplex')),
            ),
          ),
        ],
      ),
    ],
  );
}
