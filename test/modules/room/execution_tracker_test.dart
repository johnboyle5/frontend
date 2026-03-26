import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'package:soliplex_frontend/src/modules/room/execution_step.dart';
import 'package:soliplex_frontend/src/modules/room/execution_tracker.dart';

void main() {
  late Signal<ExecutionEvent?> events;
  late ExecutionTracker tracker;

  setUp(() {
    events = Signal<ExecutionEvent?>(null);
    tracker = ExecutionTracker(executionEvents: events);
  });

  tearDown(() => tracker.dispose());

  test('starts with empty steps and no thinking', () {
    expect(tracker.steps.value, isEmpty);
    expect(tracker.thinkingText.value, isEmpty);
    expect(tracker.isThinkingStreaming.value, isFalse);
  });

  test('ThinkingStarted adds an active thinking step', () {
    events.value = const ThinkingStarted();

    expect(tracker.steps.value.length, 1);
    expect(tracker.steps.value.first.label, 'Thinking');
    expect(tracker.steps.value.first.status, StepStatus.active);
    expect(tracker.isThinkingStreaming.value, isTrue);
  });

  test('ThinkingContent accumulates thinking text', () {
    events.value = const ThinkingStarted();
    events.value = const ThinkingContent(delta: 'Hello ');
    events.value = const ThinkingContent(delta: 'world');

    expect(tracker.thinkingText.value, 'Hello world');
  });

  test('ServerToolCallStarted completes previous step and adds new', () {
    events.value = const ThinkingStarted();
    events.value = const ServerToolCallStarted(
      toolName: 'search',
      toolCallId: 'tc-1',
    );

    expect(tracker.steps.value.length, 2);
    expect(tracker.steps.value[0].status, StepStatus.completed);
    expect(tracker.steps.value[0].label, 'Thinking');
    expect(tracker.steps.value[1].status, StepStatus.active);
    expect(tracker.steps.value[1].label, 'search');
    expect(tracker.isThinkingStreaming.value, isFalse);
  });

  test('ServerToolCallCompleted marks step completed', () {
    events.value = const ServerToolCallStarted(
      toolName: 'search',
      toolCallId: 'tc-1',
    );
    events.value = const ServerToolCallCompleted(
      toolCallId: 'tc-1',
      result: 'done',
    );

    expect(tracker.steps.value.length, 1);
    expect(tracker.steps.value.first.status, StepStatus.completed);
  });

  test('ClientToolExecuting adds a step', () {
    events.value = const ClientToolExecuting(
      toolName: 'calculator',
      toolCallId: 'tc-2',
    );

    expect(tracker.steps.value.length, 1);
    expect(tracker.steps.value.first.label, 'calculator');
    expect(tracker.steps.value.first.status, StepStatus.active);
  });

  test('ClientToolCompleted marks step completed', () {
    events.value = const ClientToolExecuting(
      toolName: 'calculator',
      toolCallId: 'tc-2',
    );
    events.value = const ClientToolCompleted(
      toolCallId: 'tc-2',
      result: '42',
      status: ToolCallStatus.completed,
    );

    expect(tracker.steps.value.first.status, StepStatus.completed);
  });

  test('RunCompleted marks all steps completed', () {
    events.value = const ThinkingStarted();
    events.value = const ServerToolCallStarted(
      toolName: 'search',
      toolCallId: 'tc-1',
    );
    events.value = const RunCompleted();

    for (final step in tracker.steps.value) {
      expect(step.status, StepStatus.completed);
    }
    expect(tracker.isThinkingStreaming.value, isFalse);
  });

  test('RunFailed marks all steps completed', () {
    events.value = const ThinkingStarted();
    events.value = const RunFailed(error: 'oops');

    for (final step in tracker.steps.value) {
      expect(step.status, StepStatus.completed);
    }
  });

  test('RunCancelled marks all steps completed', () {
    events.value = const ThinkingStarted();
    events.value = const RunCancelled();

    for (final step in tracker.steps.value) {
      expect(step.status, StepStatus.completed);
    }
  });

  test('dispose stops listening to events', () {
    tracker.dispose();
    events.value = const ThinkingStarted();
    expect(tracker.steps.value, isEmpty);
  });
}
