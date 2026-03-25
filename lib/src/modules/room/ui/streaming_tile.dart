import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

class StreamingTile extends StatelessWidget {
  const StreamingTile({super.key, required this.streamingState});

  final StreamingState streamingState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: switch (streamingState) {
        AwaitingText() => Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Thinking...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        TextStreaming(:final text) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(text.isEmpty ? '...' : text),
            ),
          ),
      },
    );
  }
}
