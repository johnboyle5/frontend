import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/src/core/shell.dart';
import 'package:soliplex_frontend/src/core/shell_config.dart';

void main() {
  group('SoliplexShell', () {
    test('empty config throws ArgumentError', () {
      final config = ShellConfig(
        appName: 'Test',
        theme: ThemeData(),
      );

      expect(() => runSoliplexShell(config), throwsArgumentError);
    });

    testWidgets('overrides from multiple modules compose', (tester) async {
      final greeting = Provider<String>((_) => 'default greeting');
      final farewell = Provider<String>((_) => 'default farewell');

      final config = ShellConfig(
        appName: 'Test',
        theme: ThemeData(),
        initialRoute: '/check',
        modules: [
          ModuleContribution(
            overrides: [greeting.overrideWithValue('hello')],
          ),
          ModuleContribution(
            overrides: [farewell.overrideWithValue('goodbye')],
            routes: [
              GoRoute(
                path: '/check',
                builder: (_, __) => Consumer(
                  builder: (_, ref, __) => Column(
                    children: [
                      Text(ref.watch(greeting)),
                      Text(ref.watch(farewell)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(SoliplexShell(config: config));
      await tester.pumpAndSettle();

      expect(find.text('hello'), findsOneWidget);
      expect(find.text('goodbye'), findsOneWidget);
    });
  });

  group('runSoliplexShell', () {
    test('throws ArgumentError on duplicate routes', () {
      final config = ShellConfig(
        appName: 'Test',
        theme: ThemeData(),
        modules: [
          ModuleContribution(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const SizedBox()),
            ],
          ),
          ModuleContribution(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const SizedBox()),
            ],
          ),
        ],
      );

      expect(() => runSoliplexShell(config), throwsArgumentError);
    });
  });

  group('redirect composition', () {
    testWidgets('first non-null redirect wins', (tester) async {
      final config = ShellConfig(
        appName: 'Test',
        theme: ThemeData(),
        initialRoute: '/a',
        modules: [
          ModuleContribution(
            redirect: (context, state) =>
                state.matchedLocation == '/a' ? '/b' : null,
          ),
          ModuleContribution(
            redirect: (context, state) =>
                state.matchedLocation == '/a' ? '/c' : null,
          ),
          ModuleContribution(
            routes: [
              GoRoute(
                path: '/a',
                builder: (_, __) => const Text('Page A'),
              ),
              GoRoute(
                path: '/b',
                builder: (_, __) => const Text('Page B'),
              ),
              GoRoute(
                path: '/c',
                builder: (_, __) => const Text('Page C'),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(SoliplexShell(config: config));
      await tester.pumpAndSettle();

      expect(find.text('Page B'), findsOneWidget);
    });
  });
}
