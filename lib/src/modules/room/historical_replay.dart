import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import 'execution_tracker.dart';

/// Signature for the per-event AG-UI → execution-event bridger. The
/// production implementation is the top-level [bridgeBaseEvent] from
/// `soliplex_agent`; tests inject throwing variants to exercise the
/// per-event catch in [replayToTrackers].
typedef ExecutionBridge = ExecutionEvent? Function(BaseEvent event);

final Logger _logger =
    LogManager.instance.getLogger('soliplex_frontend.historical_replay');

/// Replays stored AG-UI event bundles into one frozen [ExecutionTracker]
/// per assistant message, keyed by that message's id.
///
/// Bundle classification:
///
/// - **Normal**: contains an assistant `TextMessageStart`. Events bucket
///   under that id; any events accumulated in the hoisted `pending` from
///   prior tool-yield bundles drain into the first assistant bucket.
/// - **Tool-yield**: contains a `ToolCallStart` but no assistant
///   `TextMessageStart`. Events flow into the hoisted `pending` so the
///   next normal bundle's first assistant message absorbs them.
/// - **No-response**: neither assistant `TextMessageStart` nor
///   `ToolCallStart`. Bucket events (including any prior pending) under
///   [noResponseMessageId] for the run so the synthesized no-response
///   tile has a tracker to attach to.
///
/// When the run sequence ends with hoisted `pending` events (the last
/// bundle was tool-yield with no follow-up), the events bucket under
/// `noResponseMessageId(lastToolYieldRunId)` so they attach to the
/// no-response tile the chat-message side synthesizes for the same
/// run — the live bubble survives a reload.
///
/// A throw from [bridge] is logged at error and the offending event
/// skipped so surrounding events in the same bundle still bucket
/// correctly. The drop is deliberately UI-silent: chat-message
/// boundaries mint the drop tile; double-minting from this tracker
/// projection would surface the same backend event as two tiles.
/// [bridge] defaults to [bridgeBaseEvent] and is overridable for tests.
Map<String, ExecutionTracker> replayToTrackers(
  List<RunEventBundle> runs, {
  @visibleForTesting ExecutionBridge bridge = bridgeBaseEvent,
}) {
  final buckets = <String, List<ExecutionEvent>>{};
  // Parallel to `buckets`: the raw AG-UI events destined for each
  // tracker, retained so we can fold them through `applyActivityEvent`
  // at construction time. Bridging drops `ActivityDeltaEvent`, so the
  // bridged `ExecutionEvent` stream is insufficient for activity
  // reconstruction.
  final rawBuckets = <String, List<BaseEvent>>{};
  // Hoisted across bundles: tool-yield events accumulate here until the
  // next normal bundle's first assistant message absorbs them. If no
  // such bundle exists, the trailing handler below routes them under
  // `noResponseMessageId(lastToolYieldRunId)`.
  final pending = <ExecutionEvent>[];
  final pendingRaw = <BaseEvent>[];
  String? lastToolYieldRunId;

  ExecutionEvent? bridgeOrLog(BaseEvent raw) {
    try {
      return bridge(raw);
    } on Object catch (e, st) {
      _logger.error(
        'bridge threw on ${raw.runtimeType}; event skipped',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  for (final bundle in runs) {
    final hasAssistantStart = bundle.events.any(
      (e) => e is TextMessageStartEvent && e.role == TextMessageRole.assistant,
    );
    final hasToolCall = bundle.events.any((e) => e is ToolCallStartEvent);

    if (hasAssistantStart) {
      String? currentMessageId;
      for (final raw in bundle.events) {
        if (raw is TextMessageStartEvent &&
            raw.role == TextMessageRole.assistant) {
          final messageId = raw.messageId;
          currentMessageId = messageId;
          buckets.putIfAbsent(messageId, () => []);
          final rawBucket = rawBuckets.putIfAbsent(messageId, () => []);
          if (pending.isNotEmpty) {
            buckets[messageId]!.addAll(pending);
            pending.clear();
            rawBucket.addAll(pendingRaw);
            pendingRaw.clear();
            lastToolYieldRunId = null;
          }
        }

        final execEvent = bridgeOrLog(raw);
        if (currentMessageId != null) {
          rawBuckets.putIfAbsent(currentMessageId, () => []).add(raw);
          if (execEvent != null) {
            buckets.putIfAbsent(currentMessageId, () => []).add(execEvent);
          }
        } else {
          pendingRaw.add(raw);
          if (execEvent != null) pending.add(execEvent);
        }
      }
    } else if (hasToolCall) {
      lastToolYieldRunId = bundle.runId;
      for (final raw in bundle.events) {
        pendingRaw.add(raw);
        final execEvent = bridgeOrLog(raw);
        if (execEvent != null) pending.add(execEvent);
      }
    } else {
      final synthesizedId = noResponseMessageId(bundle.runId);
      final bucket = buckets.putIfAbsent(synthesizedId, () => []);
      final rawBucket = rawBuckets.putIfAbsent(synthesizedId, () => []);
      if (pending.isNotEmpty) {
        bucket.addAll(pending);
        pending.clear();
        rawBucket.addAll(pendingRaw);
        pendingRaw.clear();
        lastToolYieldRunId = null;
      }
      for (final raw in bundle.events) {
        rawBucket.add(raw);
        final execEvent = bridgeOrLog(raw);
        if (execEvent != null) bucket.add(execEvent);
      }
    }
  }

  // Trailing tool-yield: the chat-message side synthesizes a no-response
  // tile under `noResponseMessageId(runId)` for the same run, so route
  // the hoisted events there. Without this, the bubble disappears on
  // reload even though it was visible while the run was live.
  if (pending.isNotEmpty && lastToolYieldRunId != null) {
    final synthesizedId = noResponseMessageId(lastToolYieldRunId);
    buckets.putIfAbsent(synthesizedId, () => []).addAll(pending);
    rawBuckets.putIfAbsent(synthesizedId, () => []).addAll(pendingRaw);
    pending.clear();
    pendingRaw.clear();
  } else if (pending.isNotEmpty) {
    _logger.warning(
      'Dropping unattached events with no tool-yield runId to anchor to.',
      attributes: {'pendingCount': pending.length},
    );
    pendingRaw.clear();
  }

  return {
    for (final entry in buckets.entries)
      entry.key: ExecutionTracker.historical(
        events: entry.value,
        activities: _foldActivities(rawBuckets[entry.key] ?? const []),
        logger: _logger,
      ),
  };
}

List<ActivityRecord> _foldActivities(List<BaseEvent> events) {
  var activities = const <ActivityRecord>[];
  for (final event in events) {
    activities = applyActivityEvent(activities, event, logger: _logger);
  }
  return activities;
}
