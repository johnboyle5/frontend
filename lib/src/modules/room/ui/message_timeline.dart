import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import '../execution_tracker.dart';
import '../run_id_resolver.dart';
import 'message_tile.dart';
import 'room_welcome.dart';
import 'streaming_tile.dart';

class MessageTimeline extends StatelessWidget {
  const MessageTimeline({
    super.key,
    required this.messages,
    required this.messageStates,
    this.streamingState,
    this.executionTracker,
    this.room,
    this.onSuggestionTapped,
    this.onFeedbackSubmit,
    this.scrollController,
  });

  final List<ChatMessage> messages;
  final Map<String, MessageState> messageStates;
  final StreamingState? streamingState;
  final ExecutionTracker? executionTracker;
  final Room? room;
  final void Function(String suggestion)? onSuggestionTapped;
  final void Function(String runId, FeedbackType feedback, String? reason)?
      onFeedbackSubmit;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final hasStreaming = streamingState != null;
    final itemCount = messages.length + (hasStreaming ? 1 : 0);
    if (itemCount == 0) {
      return RoomWelcome(
        room: room,
        onSuggestionTapped: onSuggestionTapped,
        fallback: _emptyFallback(context),
      );
    }
    final runIdMap = buildRunIdMap(messages, messageStates);
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, reversedIndex) {
        if (hasStreaming && reversedIndex == 0) {
          return StreamingTile(
            key: const ValueKey('streaming'),
            streamingState: streamingState!,
            executionTracker: executionTracker,
          );
        }
        final messageIndex = hasStreaming
            ? messages.length - reversedIndex
            : messages.length - 1 - reversedIndex;
        return MessageTile(
          key: ValueKey(messages[messageIndex].id),
          message: messages[messageIndex],
          runId: runIdMap[messages[messageIndex].id],
          onFeedbackSubmit: onFeedbackSubmit,
        );
      },
    );
  }

  static Widget _emptyFallback(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48,
              color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Type a message to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
