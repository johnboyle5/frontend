import 'package:soliplex_agent/soliplex_agent.dart' hide AuthException;

import 'package:soliplex_frontend/src/modules/auth/platform/auth_flow.dart';
import 'package:soliplex_frontend/src/modules/auth/token_storage.dart';

/// Minimal HTTP client with configurable responses.
///
/// By default, throws [UnimplementedError] on every call.
/// Set [onRequest] to return controlled responses for testing.
class FakeHttpClient extends SoliplexHttpClient {
  bool closeCalled = false;

  Future<HttpResponse> Function(String method, Uri uri)? onRequest;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) {
    if (onRequest != null) return onRequest!(method, uri);
    throw UnimplementedError('FakeHttpClient.request');
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) {
    throw UnimplementedError('FakeHttpClient.requestStream');
  }

  @override
  void close() {
    closeCalled = true;
  }
}

/// Token refresh service backed by a FakeHttpClient.
/// Override [nextResult] to control test outcomes.
class FakeTokenRefreshService extends TokenRefreshService {
  FakeTokenRefreshService() : super(httpClient: FakeHttpClient());

  TokenRefreshResult? nextResult;

  @override
  Future<TokenRefreshResult> refresh({
    required String discoveryUrl,
    required String refreshToken,
    required String clientId,
  }) async {
    if (nextResult != null) return nextResult!;
    throw StateError('FakeTokenRefreshService: set nextResult before calling');
  }
}

/// HTTP observer that collects events for assertions.
class FakeHttpObserver implements HttpObserver {
  final List<HttpEvent> events = [];

  @override
  void onRequest(HttpRequestEvent event) => events.add(event);
  @override
  void onResponse(HttpResponseEvent event) => events.add(event);
  @override
  void onError(HttpErrorEvent event) => events.add(event);
  @override
  void onStreamStart(HttpStreamStartEvent event) => events.add(event);
  @override
  void onStreamEnd(HttpStreamEndEvent event) => events.add(event);
}

/// Fake AuthFlow for testing consumers that depend on AuthFlow.
class FakeAuthFlow implements AuthFlow {
  AuthResult? nextResult;
  AuthException? nextError;
  bool endSessionCalled = false;
  String? lastEndSessionDiscoveryUrl;

  @override
  Future<AuthResult> authenticate(
    AuthProviderConfig provider, {
    Uri? backendUrl,
  }) async {
    if (nextError != null) throw nextError!;
    if (nextResult != null) return nextResult!;
    throw StateError('FakeAuthFlow: set nextResult or nextError');
  }

  @override
  Future<void> endSession({
    required String discoveryUrl,
    required String? endSessionEndpoint,
    required String idToken,
    required String clientId,
  }) async {
    endSessionCalled = true;
    lastEndSessionDiscoveryUrl = discoveryUrl;
  }
}

/// In-memory token storage for tests.
class InMemoryTokenStorage implements TokenStorage {
  final Map<String, PersistedServer> _store = {};
  int saveCount = 0;

  @override
  Future<void> save(String serverId, PersistedServer data) async {
    saveCount++;
    _store[serverId] = data;
  }

  @override
  Future<void> delete(String serverId) async {
    _store.remove(serverId);
  }

  @override
  Future<Map<String, PersistedServer>> loadAll() async {
    return Map.unmodifiable(_store);
  }
}
