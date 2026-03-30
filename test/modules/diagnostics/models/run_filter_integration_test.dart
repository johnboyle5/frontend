import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/http_event_group.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/http_event_grouper.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/run_event_filter.dart';

import '../../../helpers/http_event_factories.dart';

void main() {
  test('filter + group pipeline isolates a single run from mixed traffic', () {
    final targetRunId = 'run-target';
    final otherRunId = 'run-other';

    final events = [
      createRequestEvent(
        requestId: 'req-probe',
        uri: Uri.parse('http://localhost/api/v1/auth/providers'),
        timestamp: DateTime.utc(2026, 1, 1, 12, 0),
      ),
      createResponseEvent(requestId: 'req-probe', statusCode: 200),
      createStreamStartEvent(
        requestId: 'req-target',
        uri: Uri.parse(
          'http://localhost/api/v1/rooms/room1/agui/thread1/$targetRunId',
        ),
        method: 'POST',
        timestamp: DateTime.utc(2026, 1, 1, 12, 1),
      ),
      createStreamStartEvent(
        requestId: 'req-other',
        uri: Uri.parse(
          'http://localhost/api/v1/rooms/room1/agui/thread2/$otherRunId',
        ),
        method: 'POST',
        timestamp: DateTime.utc(2026, 1, 1, 12, 2),
      ),
      createStreamEndEvent(requestId: 'req-other'),
      createStreamEndEvent(
        requestId: 'req-target',
        bytesReceived: 12000,
        duration: const Duration(seconds: 5),
      ),
    ];

    final filtered = filterEventsByRunId(events, targetRunId);
    final groups = groupHttpEvents(filtered);

    expect(groups, hasLength(1));
    expect(groups[0].requestId, 'req-target');
    expect(groups[0].isStream, isTrue);
    expect(groups[0].status, HttpEventStatus.streamComplete);
    expect(groups[0].streamEnd!.bytesReceived, 12000);
  });
}
