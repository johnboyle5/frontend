import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/auth/platform/auth_flow.dart';

void main() {
  group('AuthException', () {
    test('toString includes message', () {
      const error = AuthException('something failed');
      expect(error.toString(), 'AuthException: something failed');
    });
  });

  group('AuthRedirectInitiated', () {
    test('toString describes redirect', () {
      const error = AuthRedirectInitiated();
      expect(error.toString(), contains('redirecting'));
    });
  });

  // WebAuthFlow tests require `--platform chrome` since they import
  // package:web. They live in test/modules/auth/platform/auth_flow_web_test.dart.
}
