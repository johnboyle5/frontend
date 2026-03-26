import 'package:soliplex_agent/soliplex_agent.dart';

import 'execution_step.dart';

class ExecutionTracker {
  ExecutionTracker({
    required ReadonlySignal<ExecutionEvent?> executionEvents,
  }) {
    _stopwatch.start();
    _unsub = executionEvents.subscribe(_onEvent);
  }

  final Stopwatch _stopwatch = Stopwatch();
  void Function()? _unsub;

  final Signal<List<ExecutionStep>> _steps =
      Signal<List<ExecutionStep>>(const []);
  ReadonlySignal<List<ExecutionStep>> get steps => _steps;

  final Signal<String> _thinkingText = Signal<String>('');
  ReadonlySignal<String> get thinkingText => _thinkingText;

  final Signal<bool> _isThinkingStreaming = Signal<bool>(false);
  ReadonlySignal<bool> get isThinkingStreaming => _isThinkingStreaming;

  void _onEvent(ExecutionEvent? event) {
    if (event == null) return;
    switch (event) {
      case ThinkingStarted():
        _completeActiveStep();
        _addStep('Thinking');
        _isThinkingStreaming.value = true;
      case ThinkingContent(:final delta):
        _thinkingText.value += delta;
      case ServerToolCallStarted(:final toolName):
        _completeActiveStep();
        _isThinkingStreaming.value = false;
        _addStep(toolName);
      case ServerToolCallCompleted(:final toolCallId):
        _completeStepByToolCallId(toolCallId);
      case ClientToolExecuting(:final toolName):
        _completeActiveStep();
        _isThinkingStreaming.value = false;
        _addStep(toolName);
      case ClientToolCompleted(:final toolCallId):
        _completeStepByToolCallId(toolCallId);
      case RunCompleted() || RunFailed() || RunCancelled():
        _completeAllSteps();
        _isThinkingStreaming.value = false;
      case TextDelta() ||
            StateUpdated() ||
            StepProgress() ||
            AwaitingApproval() ||
            CustomExecutionEvent():
        break;
    }
  }

  void _addStep(String label) {
    _steps.value = [
      ..._steps.value,
      ExecutionStep(
        label: label,
        status: StepStatus.active,
        elapsed: _stopwatch.elapsed,
      ),
    ];
  }

  void _completeActiveStep() {
    final current = _steps.value;
    if (current.isEmpty) return;
    final last = current.last;
    if (last.status == StepStatus.active) {
      _steps.value = [
        ...current.sublist(0, current.length - 1),
        last.copyWith(
          status: StepStatus.completed,
          elapsed: _stopwatch.elapsed,
        ),
      ];
    }
  }

  void _completeStepByToolCallId(String toolCallId) {
    _completeActiveStep();
  }

  void _completeAllSteps() {
    final elapsed = _stopwatch.elapsed;
    _steps.value = [
      for (final step in _steps.value)
        step.status == StepStatus.active
            ? step.copyWith(status: StepStatus.completed, elapsed: elapsed)
            : step,
    ];
  }

  void dispose() {
    _unsub?.call();
    _unsub = null;
    _stopwatch.stop();
  }
}
