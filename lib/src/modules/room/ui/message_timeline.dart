import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import '../execution_tracker.dart';
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
  });

  final List<ChatMessage> messages;
  final Map<String, MessageState> messageStates;
  final StreamingState? streamingState;
  final ExecutionTracker? executionTracker;
  final Room? room;
  final void Function(String suggestion)? onSuggestionTapped;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (streamingState != null ? 1 : 0);
    if (itemCount == 0) {
      return RoomWelcome(
        room: room,
        onSuggestionTapped: onSuggestionTapped,
        fallback: _emptyFallback(context),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final isStreamingItem = index == messages.length;
        if (isStreamingItem) {
          return StreamingTile(
            key: const ValueKey('streaming'),
            streamingState: streamingState!,
            executionTracker: executionTracker,
          );
        }
        return MessageTile(
          key: ValueKey(messages[index].id),
          message: messages[index],
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
