import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:soliplex_frontend/src/core/router.dart';

GoRoute _route(String path, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, builder: (_, __) => const SizedBox(), routes: routes);

void main() {
  group('validateRoutes', () {
    test('returns empty list for valid routes', () {
      final errors = validateRoutes(
        routes: [_route('/a'), _route('/b')],
        initialRoute: '/a',
      );

      expect(errors, isEmpty);
    });

    test('returns empty list for empty routes', () {
      final errors = validateRoutes(routes: [], initialRoute: '/');

      expect(errors, isEmpty);
    });

    test('detects duplicate paths', () {
      final errors = validateRoutes(
        routes: [_route('/a'), _route('/a')],
        initialRoute: '/a',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('Duplicate'));
    });

    test('detects duplicate paths after parameterized normalization', () {
      final errors = validateRoutes(
        routes: [_route('/users/:id'), _route('/users/:userId')],
        initialRoute: '/users/:_',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('Duplicate'));
    });

    test('detects missing initial route when routes are non-empty', () {
      final errors = validateRoutes(
        routes: [_route('/a'), _route('/b')],
        initialRoute: '/missing',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('Initial route'));
    });

    test('skips initial route check when routes are empty', () {
      final errors = validateRoutes(routes: [], initialRoute: '/missing');

      expect(errors, isEmpty);
    });

    test('validates nested routes with full absolute paths', () {
      final errors = validateRoutes(
        routes: [
          _route('/parent', routes: [_route('child')]),
        ],
        initialRoute: '/parent',
      );

      expect(errors, isEmpty);
    });

    test('detects duplicate nested paths', () {
      final errors = validateRoutes(
        routes: [
          _route('/parent', routes: [_route('child')]),
          _route('/parent/child'),
        ],
        initialRoute: '/parent',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('Duplicate'));
    });

    test('initial route matches nested path', () {
      final errors = validateRoutes(
        routes: [
          _route('/parent', routes: [_route('child')]),
        ],
        initialRoute: '/parent/child',
      );

      expect(errors, isEmpty);
    });

    test('detects path shadowing - parameterized before literal sibling', () {
      final errors = validateRoutes(
        routes: [
          _route('/items', routes: [
            _route(':id'),
            _route('featured'),
          ]),
        ],
        initialRoute: '/items',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('shadow'));
    });

    test('allows literal before parameterized sibling', () {
      final errors = validateRoutes(
        routes: [
          _route('/items', routes: [
            _route('featured'),
            _route(':id'),
          ]),
        ],
        initialRoute: '/items',
      );

      expect(errors, isEmpty);
    });

    test('handles ShellRoute - passes parent path through', () {
      final errors = validateRoutes(
        routes: [
          ShellRoute(
            builder: (_, __, child) => child,
            routes: [_route('/a'), _route('/b')],
          ),
        ],
        initialRoute: '/a',
      );

      expect(errors, isEmpty);
    });

    test('handles StatefulShellRoute - iterates branches', () {
      final errors = validateRoutes(
        routes: [
          StatefulShellRoute.indexedStack(
            branches: [
              StatefulShellBranch(routes: [_route('/tab1')]),
              StatefulShellBranch(routes: [_route('/tab2')]),
            ],
            builder: (_, __, child) => child,
          ),
        ],
        initialRoute: '/tab1',
      );

      expect(errors, isEmpty);
    });

    test('detects duplicates across StatefulShellRoute branches', () {
      final errors = validateRoutes(
        routes: [
          StatefulShellRoute.indexedStack(
            branches: [
              StatefulShellBranch(routes: [_route('/tab')]),
              StatefulShellBranch(routes: [_route('/tab')]),
            ],
            builder: (_, __, child) => child,
          ),
        ],
        initialRoute: '/tab',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('Duplicate'));
    });

    // GoRoute 17.x asserts path.isNotEmpty, so empty child paths
    // cannot be constructed. Validation of empty paths is handled
    // by GoRouter itself.

    test('trailing slash normalization', () {
      final errors = validateRoutes(
        routes: [_route('/a'), _route('/a/')],
        initialRoute: '/a',
      );

      expect(errors, hasLength(1));
      expect(errors.first, contains('Duplicate'));
    });
  });
}
