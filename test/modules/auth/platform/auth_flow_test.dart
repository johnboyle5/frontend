import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/auth/platform/auth_flow.dart';

void main() {
  group('AuthResult', () {
    test('stores all token fields', () {
      final result = AuthResult(
        accessToken: 'access',
        refreshToken: 'refresh',
        idToken: 'id',
        expiresAt: DateTime(2026, 1, 1),
      );

      expect(result.accessToken, 'access');
      expect(result.refreshToken, 'refresh');
      expect(result.idToken, 'id');
      expect(result.expiresAt, DateTime(2026, 1, 1));
    });

    test('refreshToken and idToken are optional', () {
      const result = AuthResult(accessToken: 'access');

      expect(result.refreshToken, isNull);
      expect(result.idToken, isNull);
      expect(result.expiresAt, isNull);
    });
  });

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
