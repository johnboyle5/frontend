import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import '../execution_tracker.dart';
import '../room_providers.dart';
import 'copy_button.dart';
import 'execution/activity_indicator.dart';
import 'execution/execution_timeline.dart';
import 'execution/thinking_block.dart';

class NoResponseTileWidget extends StatelessWidget {
  const NoResponseTileWidget({
    super.key,
    required this.roomId,
    required this.message,
    this.executionTracker,
    this.streamingActivity,
  });

  final String roomId;
  final NoResponseTile message;
  final ExecutionTracker? executionTracker;
  final ActivityType? streamingActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTracker = executionTracker != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (streamingActivity != null)
          ActivityIndicator(activity: streamingActivity!),
        if (hasTracker)
          ExecutionTimeline(
            roomId: roomId,
            messageId: message.id,
            tracker: executionTracker!,
          ),
        if (hasTracker)
          ExecutionThinkingBlock(
            roomId: roomId,
            messageId: message.id,
            tracker: executionTracker!,
          )
        else if (message.hasThinkingText)
          _NoResponseThinkingBlock(
            roomId: roomId,
            messageId: message.id,
            text: message.thinkingText,
          ),
        Text(
          'Assistant',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        _TerminalReasonBubble(
          reason: message.reason,
          errorDetail: message.errorDetail,
        ),
      ],
    );
  }
}

class _TerminalReasonBubble extends StatelessWidget {
  const _TerminalReasonBubble({required this.reason, this.errorDetail});

  final TerminalReason reason;
  final String? errorDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label) = switch (reason) {
      TerminalReason.finished => (
          Icons.info_outline,
          'Run finished without a response',
        ),
      TerminalReason.failed => (
          Icons.error_outline,
          errorDetail != null
              ? 'Run failed: $errorDetail'
              : 'Run failed without a response',
        ),
      TerminalReason.cancelled => (
          Icons.cancel_outlined,
          'Run cancelled without a response',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResponseThinkingBlock extends ConsumerWidget {
  const _NoResponseThinkingBlock({
    required this.roomId,
    required this.messageId,
    required this.text,
  });

  final String roomId;
  final String messageId;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expansion =
        ref.read(messageExpansionsProvider).forMessage(roomId, messageId);
    return ExpansionTile(
      initiallyExpanded: expansion.thinkingExpanded,
      onExpansionChanged: (v) => expansion.thinkingExpanded = v,
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Thinking...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          CopyButton(
            text: text,
            tooltip: 'Copy thinking',
            iconSize: 16,
          ),
        ],
      ),
      dense: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      children: [
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
