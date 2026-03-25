import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'message_tile.dart';
import 'streaming_tile.dart';

class MessageTimeline extends StatelessWidget {
  const MessageTimeline({
    super.key,
    required this.messages,
    required this.messageStates,
    this.streamingState,
  });

  final List<ChatMessage> messages;
  final Map<String, MessageState> messageStates;
  final StreamingState? streamingState;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (streamingState != null ? 1 : 0);
    if (itemCount == 0) {
      return const Center(child: Text('No messages'));
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
          );
        }
        return MessageTile(
          key: ValueKey(messages[index].id),
          message: messages[index],
        );
      },
    );
  }
}
