import 'package:flutter/foundation.dart';

enum StepStatus { active, completed }

@immutable
class ExecutionStep {
  const ExecutionStep({
    required this.label,
    required this.status,
    required this.elapsed,
  });

  final String label;
  final StepStatus status;
  final Duration elapsed;

  ExecutionStep copyWith({StepStatus? status, Duration? elapsed}) =>
      ExecutionStep(
        label: label,
        status: status ?? this.status,
        elapsed: elapsed ?? this.elapsed,
      );
}
