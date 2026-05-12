/// Reproduction harness for bugs in the "$N events" bubble rendered
/// above assistant messages by [ExecutionTimeline].
///
/// Each `test` documents the failure mode it reproduces and asserts the
/// *correct* behavior — under the un-fixed code these assertions fail;
/// after the fix lands they pass without other test changes.
///
/// Bug 1 — Nested rows never get a checkmark
/// -----------------------------------------
/// Backend sends an `ACTIVITY_SNAPSHOT` for `skill_tool_call` with
/// status `in_progress`, then an `ACTIVITY_DELTA` jsonpatch (`replace
/// /status → done`) when the sub-skill completes. Before the fix the
/// frontend dropped every `ActivityDeltaEvent` at two layers:
///
/// * `bridgeBaseEvent` returned `null` for the variant.
/// * `_processActivityDelta` in `agui_event_processor.dart` was a
///   logged no-op.
///
/// Net effect: the nested row kept the in-progress status it had on
/// first paint, so its trailing icon never flipped to a checkmark.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'package:soliplex_frontend/src/modules/room/execution_tracker.dart';
import 'package:soliplex_frontend/src/modules/room/historical_replay.dart';
import 'package:soliplex_frontend/src/modules/room/ui/execution/timeline_entry.dart';

import '../../helpers/test_logger.dart';

void main() {
  group('Bug 1: ACTIVITY_DELTA status update is dropped', () {
    test(
      'bridgeBaseEvent drops ActivityDeltaEvent — nested rows never '
      'receive the status change that drives the checkmark',
      () {
        final delta = ActivityDeltaEvent(
          messageId: 'rag:call_1',
          activityType: 'skill_tool_call',
          patch: const [
            {'op': 'replace', 'path': '/status', 'value': 'done'},
          ],
          timestamp: 200,
        );

        // Correct behavior: produce an ExecutionEvent the tracker can act
        // on so the activity's status moves to "done". Currently null.
        expect(
          bridgeBaseEvent(delta),
          isNotNull,
          reason: 'Bug 1: ActivityDeltaEvent is dropped at the bridge; '
              'the timeline never sees the status change.',
        );
      },
    );

    test(
      'historical replay: snapshot(in_progress) + delta(status→done) '
      'leaves the nested activity stuck at in_progress',
      () {
        final runs = [
          RunEventBundle(
            runId: 'run-1',
            events: const [
              TextMessageStartEvent(messageId: 'asst-1'),
              ToolCallStartEvent(
                toolCallId: 'tc-1',
                toolCallName: 'execute_skill',
              ),
              ActivitySnapshotEvent(
                messageId: 'rag:call_1',
                activityType: 'skill_tool_call',
                content: {
                  'tool_name': 'ask',
                  'args': '{"q":"hi"}',
                  'status': 'in_progress',
                },
                timestamp: 100,
              ),
              ActivityDeltaEvent(
                messageId: 'rag:call_1',
                activityType: 'skill_tool_call',
                patch: [
                  {'op': 'replace', 'path': '/status', 'value': 'done'},
                ],
                timestamp: 150,
              ),
              ToolCallResultEvent(
                toolCallId: 'tc-1',
                content: 'ok',
                messageId: 'result-1',
              ),
              TextMessageEndEvent(messageId: 'asst-1'),
            ],
          ),
        ];

        final trackers = replayToTrackers(runs);
        final step = trackers['asst-1']!.timeline.value.single as TimelineStep;

        expect(step.activities, hasLength(1));
        expect(
          step.activities.single.status,
          'done',
          reason: 'Bug 1: ACTIVITY_DELTA patches are dropped during replay; '
              'the nested activity stays at its initial in_progress status.',
        );
      },
    );

    test(
      'live tracker: ActivitySnapshot then ActivityDelta on the same '
      'messageId does not advance the activity to done',
      () {
        final events = Signal<ExecutionEvent?>(null);
        final tracker = ExecutionTracker(
          executionEvents: events,
          logger: testLogger(),
        );
        addTearDown(tracker.dispose);

        // Bridge each AG-UI event through the production bridge, mirroring
        // what AgentSession does at runtime. Anything the bridge drops
        // never reaches the tracker — exactly the bug we're reproducing.
        final ExecutionEvent? snapshot = bridgeBaseEvent(
          const ActivitySnapshotEvent(
            messageId: 'rag:call_1',
            activityType: 'skill_tool_call',
            content: {
              'tool_name': 'ask',
              'args': '{"q":"hi"}',
              'status': 'in_progress',
            },
            timestamp: 100,
          ),
        );
        expect(snapshot, isNotNull);
        events.value = snapshot;

        final ExecutionEvent? delta = bridgeBaseEvent(
          ActivityDeltaEvent(
            messageId: 'rag:call_1',
            activityType: 'skill_tool_call',
            patch: const [
              {'op': 'replace', 'path': '/status', 'value': 'done'},
            ],
            timestamp: 200,
          ),
        );

        expect(
          delta,
          isNotNull,
          reason: 'Bug 1: the bridge drops the delta before it can reach '
              'the live tracker.',
        );
        if (delta != null) events.value = delta;

        final calls = tracker.skillToolCalls.value;
        expect(calls, hasLength(1));
        expect(
          calls.single.status,
          'done',
          reason: 'Bug 1: live tracker never sees the delta-driven '
              'status change; the trailing icon stays as a spinner.',
        );
      },
    );
  });
}
