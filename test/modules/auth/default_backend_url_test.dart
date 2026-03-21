import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soliplex_frontend/src/modules/auth/default_backend_url.dart';

void main() {
  group('platformDefaultBackendUrl', () {
    test('returns configUrl when not web', () {
      final result = platformDefaultBackendUrl(
        configUrl: 'http://localhost:8000',
      );
      expect(result, 'http://localhost:8000');
    });

    test('returns configUrl when web + localhost', () {
      final result = platformDefaultBackendUrl(
        configUrl: 'http://localhost:8000',
        isWeb: true,
        webOrigin: Uri.parse('http://localhost:3000'),
      );
      expect(result, 'http://localhost:8000');
    });

    test('returns configUrl when web + 127.0.0.1', () {
      final result = platformDefaultBackendUrl(
        configUrl: 'http://localhost:8000',
        isWeb: true,
        webOrigin: Uri.parse('http://127.0.0.1:3000'),
      );
      expect(result, 'http://localhost:8000');
    });

    test('returns origin when web + remote host', () {
      final result = platformDefaultBackendUrl(
        configUrl: 'http://localhost:8000',
        isWeb: true,
        webOrigin: Uri.parse('https://app.example.com/'),
      );
      expect(result, 'https://app.example.com');
    });
  });

  group('DefaultBackendUrlStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns null when nothing saved', () async {
      final result = await DefaultBackendUrlStorage.load();
      expect(result, isNull);
    });

    test('load returns null for empty string', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backend_base_url', '');
      final result = await DefaultBackendUrlStorage.load();
      expect(result, isNull);
    });
  });
}
