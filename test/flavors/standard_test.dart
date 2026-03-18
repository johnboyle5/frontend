import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:soliplex_frontend/flavors.dart';
import 'package:soliplex_frontend/soliplex_frontend.dart';

void main() {
  group('standard()', () {
    test('includes a root route', () {
      final config = standard();
      final paths = config.routes.whereType<GoRoute>().map((r) => r.path);
      expect(paths, contains('/'));
    });

    test('provides Unauthenticated as initial auth state', () {
      final config = standard();
      final container = ProviderContainer(overrides: config.overrides);
      addTearDown(container.dispose);

      expect(container.read(authStateProvider), isA<Unauthenticated>());
    });
  });
}
