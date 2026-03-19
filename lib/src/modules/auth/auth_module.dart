import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide AuthException;

import '../../core/shell_config.dart';
import '../../interfaces/auth_state.dart';
import 'auth_providers.dart';
import 'consent_notice.dart';
import 'platform/auth_flow.dart';
import 'platform/callback_params.dart';
import 'server_manager.dart';

/// Public routes that don't require authentication.
const _publicPaths = {'/', '/servers/add', '/auth/callback'};

ModuleContribution authModule({
  required ServerManager serverManager,
  required AuthFlow authFlow,
  required SoliplexHttpClient probeClient,
  CallbackParams? callbackParams,
  ConsentNotice? consentNotice,
  Widget? logo,
}) {
  return ModuleContribution(
    overrides: [
      serverManagerProvider.overrideWithValue(serverManager),
      authFlowProvider.overrideWithValue(authFlow),
      probeClientProvider.overrideWithValue(probeClient),
      if (callbackParams != null)
        callbackParamsProvider.overrideWithValue(callbackParams),
      if (consentNotice != null)
        consentNoticeProvider.overrideWithValue(consentNotice),
      if (logo != null) logoProvider.overrideWithValue(logo),
    ],
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Home (placeholder)')),
        ),
      ),
      GoRoute(
        path: '/servers/add',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Add Server (placeholder)')),
        ),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Auth Callback (placeholder)')),
        ),
      ),
    ],
    redirect: (_, state) {
      final isAuthenticated = serverManager.authState.value is Authenticated;
      final isPublic = _publicPaths.contains(state.matchedLocation);

      if (!isAuthenticated && !isPublic) return '/';
      return null;
    },
  );
}
