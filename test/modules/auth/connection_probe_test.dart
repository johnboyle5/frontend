import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_frontend/src/modules/auth/connection_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

const _provider = AuthProviderConfig(
  id: 'keycloak',
  name: 'Keycloak',
  serverUrl: 'https://sso.example.com/realms/app',
  clientId: 'soliplex',
  scope: 'openid email profile',
);

void main() {
  group('normalizeServerUrl', () {
    test('adds https scheme when missing', () {
      expect(
        normalizeServerUrl('example.com'),
        Uri.parse('https://example.com'),
      );
    });

    test('preserves explicit https scheme', () {
      expect(
        normalizeServerUrl('https://example.com'),
        Uri.parse('https://example.com'),
      );
    });

    test('preserves explicit http scheme', () {
      expect(
        normalizeServerUrl('http://example.com'),
        Uri.parse('http://example.com'),
      );
    });

    test('strips trailing slash', () {
      expect(
        normalizeServerUrl('https://example.com/'),
        Uri.parse('https://example.com'),
      );
    });

    test('trims whitespace', () {
      expect(
        normalizeServerUrl('  example.com  '),
        Uri.parse('https://example.com'),
      );
    });

    test('preserves path segments', () {
      expect(
        normalizeServerUrl('example.com/api/v1/'),
        Uri.parse('https://example.com/api/v1'),
      );
    });

    test('adds https scheme to host:port input', () {
      expect(
        normalizeServerUrl('localhost:8000'),
        Uri.parse('https://localhost:8000'),
      );
    });

    test('adds https scheme to IP:port input', () {
      expect(
        normalizeServerUrl('192.168.1.1:8000'),
        Uri.parse('https://192.168.1.1:8000'),
      );
    });

    test('adds https scheme to domain:port input', () {
      expect(
        normalizeServerUrl('example.com:443'),
        Uri.parse('https://example.com:443'),
      );
    });

    test('throws FormatException for empty input', () {
      expect(() => normalizeServerUrl(''), throwsFormatException);
    });

    test('throws FormatException for whitespace-only input', () {
      expect(() => normalizeServerUrl('   '), throwsFormatException);
    });
  });

  group('probeConnection', () {
    late FakeHttpClient httpClient;

    setUp(() {
      httpClient = FakeHttpClient();
    });

    test('returns success when HTTPS probe succeeds', () async {
      final result = await probeConnection(
        input: 'example.com',
        httpClient: httpClient,
        discover: (serverUrl, _) async => [_provider],
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.serverUrl, Uri.parse('https://example.com'));
      expect(success.providers, [_provider]);
      expect(success.isInsecure, isFalse);
    });

    test('falls back to HTTP on NetworkException for schemeless input',
        () async {
      var callCount = 0;
      final result = await probeConnection(
        input: 'example.com',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          callCount++;
          if (serverUrl.scheme == 'https') {
            throw const NetworkException(message: 'connection refused');
          }
          return [_provider];
        },
      );

      expect(callCount, 2);
      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.serverUrl, Uri.parse('http://example.com'));
      expect(success.isInsecure, isTrue);
    });

    test('falls back to HTTP for host:port schemeless input', () async {
      final result = await probeConnection(
        input: 'localhost:8000',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          if (serverUrl.scheme == 'https') {
            throw const NetworkException(message: 'connection refused');
          }
          return [_provider];
        },
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.serverUrl, Uri.parse('http://localhost:8000'));
      expect(success.isInsecure, isTrue);
    });

    test('does not fall back for explicit https:// input', () async {
      final result = await probeConnection(
        input: 'https://example.com',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          throw const NetworkException(message: 'connection refused');
        },
      );

      expect(result, isA<ConnectionFailure>());
    });

    test('does not fall back for explicit http:// input', () async {
      var callCount = 0;
      final result = await probeConnection(
        input: 'http://example.com',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          callCount++;
          if (callCount == 1) {
            return [_provider];
          }
          throw StateError('should not be called twice');
        },
      );

      expect(callCount, 1);
      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.serverUrl, Uri.parse('http://example.com'));
      expect(success.isInsecure, isTrue);
    });

    test('returns failure for non-network exception', () async {
      final result = await probeConnection(
        input: 'example.com',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          throw Exception('server returned 500');
        },
      );

      expect(result, isA<ConnectionFailure>());
      final failure = result as ConnectionFailure;
      expect(failure.error, isA<Exception>());
    });

    test('returns failure when both HTTPS and HTTP fail with NetworkException',
        () async {
      final result = await probeConnection(
        input: 'example.com',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          throw const NetworkException(message: 'unreachable');
        },
      );

      expect(result, isA<ConnectionFailure>());
      final failure = result as ConnectionFailure;
      expect(failure.error, isA<NetworkException>());
    });

    test('trims whitespace from input', () async {
      Uri? capturedUrl;
      await probeConnection(
        input: '  example.com  ',
        httpClient: httpClient,
        discover: (serverUrl, _) async {
          capturedUrl = serverUrl;
          return [_provider];
        },
      );

      expect(capturedUrl, Uri.parse('https://example.com'));
    });

    test('returns failure for empty input', () async {
      final result = await probeConnection(
        input: '',
        httpClient: httpClient,
        discover: (_, __) async => throw StateError('should not be called'),
      );

      expect(result, isA<ConnectionFailure>());
    });

    test('times out and falls back to HTTP for schemeless input', () async {
      var callCount = 0;
      final result = await probeConnection(
        input: 'example.com',
        httpClient: httpClient,
        probeTimeout: const Duration(milliseconds: 100),
        discover: (serverUrl, _) async {
          callCount++;
          if (serverUrl.scheme == 'https') {
            // Simulate a hanging HTTPS connection.
            await Future<void>.delayed(const Duration(seconds: 10));
            throw StateError('should have timed out');
          }
          return [_provider];
        },
      );

      expect(callCount, 2);
      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.serverUrl, Uri.parse('http://example.com'));
      expect(success.isInsecure, isTrue);
    });

    test('times out and returns failure for explicit scheme', () async {
      final result = await probeConnection(
        input: 'https://example.com',
        httpClient: httpClient,
        probeTimeout: const Duration(milliseconds: 100),
        discover: (serverUrl, _) async {
          await Future<void>.delayed(const Duration(seconds: 10));
          throw StateError('should have timed out');
        },
      );

      expect(result, isA<ConnectionFailure>());
      final failure = result as ConnectionFailure;
      expect(failure.error, isA<NetworkException>());
      expect((failure.error as NetworkException).isTimeout, isTrue);
    });

    test('normalizes URL in success result (strips trailing slash)', () async {
      final result = await probeConnection(
        input: 'example.com/',
        httpClient: httpClient,
        discover: (serverUrl, _) async => [_provider],
      );

      final success = result as ConnectionSuccess;
      expect(success.serverUrl, Uri.parse('https://example.com'));
    });
  });
}
