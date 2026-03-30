import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/format_utils.dart';

void main() {
  group('HttpTimestampFormat', () {
    test('pads single-digit hours, minutes, seconds', () {
      final dt = DateTime.utc(2026, 1, 1, 1, 2, 3);
      expect(dt.toHttpTimeString(), '01:02:03');
    });

    test('formats double-digit values', () {
      final dt = DateTime.utc(2026, 1, 1, 23, 59, 59);
      expect(dt.toHttpTimeString(), '23:59:59');
    });
  });

  group('HttpDurationFormat', () {
    test('formats sub-second as milliseconds', () {
      expect(const Duration(milliseconds: 45).toHttpDurationString(), '45ms');
    });

    test('formats exactly 1 second', () {
      expect(const Duration(seconds: 1).toHttpDurationString(), '1.0s');
    });

    test('formats sub-minute as seconds', () {
      expect(const Duration(milliseconds: 1500).toHttpDurationString(), '1.5s');
    });

    test('formats exactly 1 minute', () {
      expect(const Duration(minutes: 1).toHttpDurationString(), '1.0m');
    });

    test('formats over 1 minute', () {
      expect(const Duration(seconds: 90).toHttpDurationString(), '1.5m');
    });

    test('formats zero duration', () {
      expect(Duration.zero.toHttpDurationString(), '0ms');
    });

    test('boundary at 999ms stays in ms', () {
      expect(const Duration(milliseconds: 999).toHttpDurationString(), '999ms');
    });
  });

  group('HttpBytesFormat', () {
    test('formats bytes under 1KB', () {
      expect(500.toHttpBytesString(), '500B');
    });

    test('formats exactly 1KB', () {
      expect(1024.toHttpBytesString(), '1.0KB');
    });

    test('formats kilobytes', () {
      expect(2560.toHttpBytesString(), '2.5KB');
    });

    test('formats exactly 1MB', () {
      expect((1024 * 1024).toHttpBytesString(), '1.0MB');
    });

    test('formats megabytes', () {
      expect((1024 * 1024 * 3).toHttpBytesString(), '3.0MB');
    });

    test('formats zero bytes', () {
      expect(0.toHttpBytesString(), '0B');
    });

    test('boundary at 1023 bytes stays in B', () {
      expect(1023.toHttpBytesString(), '1023B');
    });
  });
}
