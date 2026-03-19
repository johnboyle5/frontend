import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/src/modules/auth/auth_module.dart';
import 'package:soliplex_frontend/src/modules/auth/auth_session.dart';
import 'package:soliplex_frontend/src/modules/auth/auth_tokens.dart';
import 'package:soliplex_frontend/src/modules/auth/server_manager.dart';

import '../../helpers/fakes.dart';

ServerManager _createServerManager() => ServerManager(
      authFactory: () => AuthSession(
        refreshService: FakeTokenRefreshService(),
      ),
      clientFactory: ({getToken, tokenRefresher}) => FakeHttpClient(),
      storage: InMemoryTokenStorage(),
    );

void main() {
  group('authModule', () {
    test('contributes routes for /, /servers/add, /auth/callback', () {
      final serverManager = _createServerManager();
      final contribution = authModule(
        serverManager: serverManager,
        authFlow: FakeAuthFlow(),
        probeClient: FakeHttpClient(),
      );

      final paths =
          contribution.routes.whereType<GoRoute>().map((r) => r.path).toList();
      expect(paths, containsAll(['/', '/servers/add', '/auth/callback']));
    });

    test('contributes a redirect', () {
      final serverManager = _createServerManager();
      final contribution = authModule(
        serverManager: serverManager,
        authFlow: FakeAuthFlow(),
        probeClient: FakeHttpClient(),
      );

      expect(contribution.redirect, isNotNull);
    });

    test('contributes overrides for required providers', () {
      final serverManager = _createServerManager();
      final contribution = authModule(
        serverManager: serverManager,
        authFlow: FakeAuthFlow(),
        probeClient: FakeHttpClient(),
      );

      // At minimum: serverManager, authFlow, probeClient.
      // Optional overrides only added when non-null.
      expect(contribution.overrides, isNotEmpty);
    });
  });

  group('auth redirect', () {
    late ServerManager serverManager;
    late GoRouter router;

    Widget buildApp() {
      final contribution = authModule(
        serverManager: serverManager,
        authFlow: FakeAuthFlow(),
        probeClient: FakeHttpClient(),
      );

      router = GoRouter(
        initialLocation: '/',
        routes: [
          ...contribution.routes,
          GoRoute(
            path: '/chat',
            builder: (_, __) => const Text('Chat'),
          ),
        ],
        redirect: contribution.redirect,
      );

      return ProviderScope(
        overrides: contribution.overrides,
        child: MaterialApp.router(routerConfig: router),
      );
    }

    setUp(() {
      serverManager = _createServerManager();
    });

    testWidgets('stays on / when unauthenticated', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Home (placeholder)'), findsOneWidget);
    });

    testWidgets('redirects /chat to / when unauthenticated', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      router.go('/chat');
      await tester.pumpAndSettle();

      expect(find.text('Home (placeholder)'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
    });

    testWidgets('allows /chat when authenticated', (tester) async {
      final entry = serverManager.addServer(
        serverId: 'test',
        serverUrl: Uri.parse('https://api.example.com'),
      );
      entry.auth.login(
        provider: const OidcProvider(
          discoveryUrl:
              'https://sso.example.com/.well-known/openid-configuration',
          clientId: 'soliplex',
        ),
        tokens: AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      router.go('/chat');
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('allows /servers/add when unauthenticated', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      router.go('/servers/add');
      await tester.pumpAndSettle();

      expect(find.text('Add Server (placeholder)'), findsOneWidget);
    });
  });
}
