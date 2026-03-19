import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/auth/platform/callback_service.dart';

void main() {
  group('NoCallbackParams', () {
    test('error is null', () {
      const params = NoCallbackParams();
      expect(params.error, isNull);
      expect(params.hasError, isFalse);
    });
  });

  group('WebCallbackParams', () {
    test('stores token fields', () {
      const params = WebCallbackParams(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
      );

      expect(params.accessToken, 'access');
      expect(params.refreshToken, 'refresh');
      expect(params.expiresIn, 3600);
      expect(params.hasError, isFalse);
    });

    test('stores error fields', () {
      const params = WebCallbackParams(
        error: 'access_denied',
        errorDescription: 'User cancelled',
      );

      expect(params.accessToken, isNull);
      expect(params.error, 'access_denied');
      expect(params.errorDescription, 'User cancelled');
      expect(params.hasError, isTrue);
    });

    test('all fields are optional', () {
      const params = WebCallbackParams();

      expect(params.accessToken, isNull);
      expect(params.refreshToken, isNull);
      expect(params.expiresIn, isNull);
      expect(params.error, isNull);
      expect(params.errorDescription, isNull);
    });
  });

  group('CallbackParamsCapture', () {
    test('captureNow returns NoCallbackParams on native', () {
      final params = CallbackParamsCapture.captureNow();
      expect(params, isA<NoCallbackParams>());
    });
  });

  group('clearCallbackUrl', () {
    test('is a no-op on native', () {
      // Should not throw.
      clearCallbackUrl();
    });
  });
}
