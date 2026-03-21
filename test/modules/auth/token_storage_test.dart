import 'package:flutter_test/flutter_test.dart';

import 'package:soliplex_frontend/src/modules/auth/auth_tokens.dart';
import 'package:soliplex_frontend/src/modules/auth/token_storage.dart';

const _provider = OidcProvider(
  discoveryUrl: 'https://auth.example.com/.well-known/openid-configuration',
  clientId: 'test-client',
);

final _tokens = AuthTokens(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: DateTime.utc(2026, 1, 1, 12),
  idToken: 'id-tok',
);

void main() {
  group('PersistedServer', () {
    test('AuthenticatedServer toJson/fromJson round-trip', () {
      final original = AuthenticatedServer(
        serverUrl: Uri.parse('https://api.example.com'),
        provider: _provider,
        tokens: _tokens,
      );

      final json = original.toJson();
      final restored = PersistedServer.fromJson(json);

      expect(restored, isA<AuthenticatedServer>());
      final auth = restored as AuthenticatedServer;
      expect(auth.serverUrl, original.serverUrl);
      expect(auth.provider.discoveryUrl, original.provider.discoveryUrl);
      expect(auth.provider.clientId, original.provider.clientId);
      expect(auth.tokens.accessToken, original.tokens.accessToken);
      expect(auth.tokens.refreshToken, original.tokens.refreshToken);
      expect(auth.tokens.expiresAt, original.tokens.expiresAt);
      expect(auth.tokens.idToken, original.tokens.idToken);
    });

    test('KnownServer toJson/fromJson round-trip', () {
      final original = KnownServer(
        serverUrl: Uri.parse('http://localhost:8000'),
      );

      final json = original.toJson();
      final restored = PersistedServer.fromJson(json);

      expect(restored, isA<KnownServer>());
      expect(restored.serverUrl, original.serverUrl);
      expect(restored.requiresAuth, isTrue);
    });

    test('KnownServer toJson/fromJson with requiresAuth false', () {
      final original = KnownServer(
        serverUrl: Uri.parse('http://localhost:8000'),
        requiresAuth: false,
      );

      final json = original.toJson();
      final restored = PersistedServer.fromJson(json);

      expect(restored, isA<KnownServer>());
      expect(restored.requiresAuth, isFalse);
    });
  });
}
