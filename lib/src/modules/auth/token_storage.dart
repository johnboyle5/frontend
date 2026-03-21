import 'package:shared_preferences/shared_preferences.dart';

import 'auth_tokens.dart';

/// Data persisted per server for session restoration.
sealed class PersistedServer {
  const PersistedServer({required this.serverUrl, this.requiresAuth = true});

  factory PersistedServer.fromJson(Map<String, dynamic> json) {
    final serverUrl = Uri.parse(json['serverUrl'] as String);
    final requiresAuth = json['requiresAuth'] as bool? ?? true;
    final providerJson = json['provider'] as Map<String, dynamic>?;
    final tokensJson = json['tokens'] as Map<String, dynamic>?;
    if (providerJson != null && tokensJson != null) {
      return AuthenticatedServer(
        serverUrl: serverUrl,
        requiresAuth: requiresAuth,
        provider: OidcProvider.fromJson(providerJson),
        tokens: AuthTokens.fromJson(tokensJson),
      );
    }
    return KnownServer(serverUrl: serverUrl, requiresAuth: requiresAuth);
  }

  final Uri serverUrl;
  final bool requiresAuth;

  Map<String, dynamic> toJson();
}

/// A server with active auth credentials.
class AuthenticatedServer extends PersistedServer {
  const AuthenticatedServer({
    required super.serverUrl,
    super.requiresAuth,
    required this.provider,
    required this.tokens,
  });

  final OidcProvider provider;
  final AuthTokens tokens;

  @override
  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl.toString(),
        'requiresAuth': requiresAuth,
        'provider': provider.toJson(),
        'tokens': tokens.toJson(),
      };
}

/// A known server without auth credentials.
class KnownServer extends PersistedServer {
  const KnownServer({required super.serverUrl, super.requiresAuth});

  @override
  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl.toString(),
        'requiresAuth': requiresAuth,
      };
}

/// Abstraction for persisting auth tokens per server.
abstract class TokenStorage {
  Future<void> save(String serverId, PersistedServer data);
  Future<void> delete(String serverId);
  Future<Map<String, PersistedServer>> loadAll();
}

const _freshInstallKey = 'soliplex_has_launched';

/// Clears stored tokens on first launch after a fresh install.
///
/// iOS/macOS Keychain persists across app uninstalls. SharedPreferences
/// does not, so a missing flag means this is a fresh install.
Future<void> clearTokensIfFreshInstall(TokenStorage storage) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_freshInstallKey) == true) return;

  final all = await storage.loadAll();
  for (final serverId in all.keys) {
    await storage.delete(serverId);
  }
  await prefs.setBool(_freshInstallKey, true);
}
