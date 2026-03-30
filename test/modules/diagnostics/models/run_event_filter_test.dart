import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/run_event_filter.dart';

import '../../../helpers/http_event_factories.dart';

void main() {
  group('filterEventsByRunId', () {
    test('returns events whose URI path contains the runId', () {
      final runId = 'run-abc-123';
      final events = [
        createStreamStartEvent(
          requestId: 'req-1',
          uri: Uri.parse(
            'http://localhost/api/v1/rooms/room1/agui/thread1/$runId',
          ),
        ),
        createStreamEndEvent(requestId: 'req-1'),
      ];
      final filtered = filterEventsByRunId(events, runId);
      expect(filtered, hasLength(2));
    });

    test('excludes events with non-matching URIs', () {
      final events = [
        createRequestEvent(
          requestId: 'req-1',
          uri: Uri.parse('http://localhost/api/v1/rooms/room1/agui'),
        ),
        createResponseEvent(requestId: 'req-1'),
      ];
      final filtered = filterEventsByRunId(events, 'run-abc-123');
      expect(filtered, isEmpty);
    });

    test('does not false-positive on partial runId match', () {
      final events = [
        createStreamStartEvent(
          requestId: 'req-1',
          uri: Uri.parse(
            'http://localhost/api/v1/rooms/room1/agui/thread1/run-abc-1234',
          ),
        ),
      ];
      final filtered = filterEventsByRunId(events, 'run-abc-123');
      expect(filtered, isEmpty);
    });

    test('includes response/error/streamEnd events matching the requestId', () {
      final runId = 'run-xyz';
      final events = [
        createStreamStartEvent(
          requestId: 'req-1',
          uri: Uri.parse(
            'http://localhost/api/v1/rooms/room1/agui/thread1/$runId',
          ),
        ),
        createStreamEndEvent(requestId: 'req-1'),
        createRequestEvent(
          requestId: 'req-2',
          uri: Uri.parse('http://localhost/api/v1/other'),
        ),
        createResponseEvent(requestId: 'req-2'),
      ];
      final filtered = filterEventsByRunId(events, runId);
      expect(filtered, hasLength(2));
      expect(filtered.every((e) => e.requestId == 'req-1'), isTrue);
    });

    test('returns empty list when no events match', () {
      final events = [
        createRequestEvent(requestId: 'req-1'),
        createResponseEvent(requestId: 'req-1'),
      ];
      final filtered = filterEventsByRunId(events, 'nonexistent-run');
      expect(filtered, isEmpty);
    });
  });
}
