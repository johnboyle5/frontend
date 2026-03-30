import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/http_event_group.dart';

import '../../../helpers/http_event_factories.dart';

void main() {
  group('HttpEventGroup', () {
    group('status', () {
      test('returns pending when only request exists', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(),
        );
        expect(group.status, HttpEventStatus.pending);
      });

      test('returns success for 2xx response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(),
          response: createResponseEvent(statusCode: 200),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns clientError for 4xx response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(),
          response: createResponseEvent(statusCode: 404),
        );
        expect(group.status, HttpEventStatus.clientError);
      });

      test('returns serverError for 5xx response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(),
          response: createResponseEvent(statusCode: 500),
        );
        expect(group.status, HttpEventStatus.serverError);
      });

      test('returns networkError when error event exists', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(),
          error: createErrorEvent(),
        );
        expect(group.status, HttpEventStatus.networkError);
      });

      test('returns streaming when streamStart exists but no streamEnd', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: createStreamStartEvent(),
        );
        expect(group.status, HttpEventStatus.streaming);
      });

      test('returns streamComplete when stream ends without error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: createStreamStartEvent(),
          streamEnd: createStreamEndEvent(),
        );
        expect(group.status, HttpEventStatus.streamComplete);
      });

      test('returns streamError when stream ends with error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: createStreamStartEvent(),
          streamEnd: createStreamEndEvent(
            error: const NetworkException(message: 'Stream failed'),
          ),
        );
        expect(group.status, HttpEventStatus.streamError);
      });
    });

    group('method', () {
      test('extracts from request event', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(method: 'POST'),
        );
        expect(group.method, 'POST');
      });

      test('extracts from error event when no request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: createErrorEvent(method: 'DELETE'),
        );
        expect(group.method, 'DELETE');
      });

      test('extracts from streamStart when no request or error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: createStreamStartEvent(method: 'POST'),
        );
        expect(group.method, 'POST');
      });

      test('throws StateError when no events have method', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(() => group.method, throwsStateError);
      });
    });

    group('toCurl', () {
      test('generates curl for GET request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(
            method: 'GET',
            uri: Uri.parse('http://localhost/api/v1/rooms'),
          ),
        );
        final curl = group.toCurl();
        expect(curl, contains("'http://localhost/api/v1/rooms'"));
        expect(curl, isNot(contains('-X')));
      });

      test('generates curl with method for non-GET', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: createRequestEvent(
            method: 'POST',
            uri: Uri.parse('http://localhost/api/v1/rooms'),
            body: '{"prompt":"hello"}',
          ),
        );
        final curl = group.toCurl();
        expect(curl, contains('-X POST'));
        expect(curl, contains('-d'));
      });

      test('returns null when no request data', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          response: createResponseEvent(),
        );
        expect(group.toCurl(), isNull);
      });
    });

    group('formatBody', () {
      test('pretty-prints JSON map', () {
        final result = HttpEventGroup.formatBody({'key': 'value'});
        expect(result, contains('"key": "value"'));
      });

      test('pretty-prints JSON string', () {
        final result = HttpEventGroup.formatBody('{"key":"value"}');
        expect(result, contains('"key": "value"'));
      });

      test('returns original string for non-JSON', () {
        expect(HttpEventGroup.formatBody('plain text'), 'plain text');
      });

      test('returns empty string for null', () {
        expect(HttpEventGroup.formatBody(null), '');
      });
    });
  });
}
