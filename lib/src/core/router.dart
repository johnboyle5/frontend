import 'package:flutter/widgets.dart' show BuildContext;
import 'package:go_router/go_router.dart';

import 'shell_config.dart';

/// Validates route configuration and returns a list of error descriptions.
/// An empty list means the configuration is valid.
List<String> validateRoutes({
  required List<RouteBase> routes,
  required String initialRoute,
}) {
  final errors = <String>[];
  final paths = <String>[];

  void walkRoutes(List<RouteBase> routes, String parentPath) {
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      if (route is GoRoute) {
        final segment = route.path;
        final fullPath = _joinPath(parentPath, segment);
        final normalized = _normalizePath(fullPath);

        // Check for path shadowing among siblings
        if (_isParameterized(segment)) {
          final laterLiterals = routes
              .skip(i + 1)
              .whereType<GoRoute>()
              .where((r) => !_isParameterized(r.path));
          if (laterLiterals.isNotEmpty) {
            errors.add(
              'Path shadowing: parameterized segment "$segment" at '
              '"$fullPath" appears before literal sibling(s) '
              '${laterLiterals.map((r) => '"${r.path}"').join(', ')}',
            );
          }
        }

        paths.add(normalized);

        walkRoutes(route.routes, fullPath);
      } else if (route is StatefulShellRoute) {
        for (final branch in route.branches) {
          walkRoutes(branch.routes, parentPath);
        }
      } else if (route is ShellRoute) {
        walkRoutes(route.routes, parentPath);
      }
    }
  }

  if (routes.isEmpty) {
    return ['Configuration must define at least one route'];
  }

  walkRoutes(routes, '');

  // Check for duplicate paths
  final seen = <String>{};
  for (final path in paths) {
    if (!seen.add(path)) {
      errors.add('Duplicate route path: "$path"');
    }
  }

  final normalizedInitial = _normalizePath(initialRoute);
  if (!paths.contains(normalizedInitial)) {
    errors.add(
      'Initial route "$initialRoute" does not match any defined route. '
      'Available: ${paths.join(', ')}',
    );
  }

  return errors;
}

String _joinPath(String parent, String segment) {
  if (segment.isEmpty) return parent;
  if (segment.startsWith('/')) return segment;
  if (parent.isEmpty) return '/$segment';
  final base =
      parent.endsWith('/') ? parent.substring(0, parent.length - 1) : parent;
  return '$base/$segment';
}

String _normalizePath(String path) {
  // Strip trailing slash (except for root)
  var normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  // Normalize parameterized segments: :anything -> :_
  normalized = normalized.replaceAll(RegExp(r':[^/]+'), ':_');
  return normalized;
}

bool _isParameterized(String segment) => segment.startsWith(':');

/// Creates a [GoRouter] from a validated [ShellConfig].
///
/// All module redirects collapse into a single GoRouter redirect slot —
/// they are evaluated in module order and the first non-null result wins.
///
/// Expects routes to be non-empty (enforced by [validateRoutes]).
GoRouter buildRouter(ShellConfig config) {
  return GoRouter(
    initialLocation: config.initialRoute,
    routes: config.routes,
    redirect: config.redirects.isEmpty
        ? null
        : (BuildContext context, GoRouterState state) async {
            for (final redirect in config.redirects) {
              final result = await redirect(context, state);
              if (result != null) return result;
            }
            return null;
          },
  );
}
