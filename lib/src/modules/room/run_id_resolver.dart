import 'package:soliplex_agent/soliplex_agent.dart';

Map<String, String?> buildRunIdMap(
  List<ChatMessage> messages,
  Map<String, MessageState> messageStates,
) {
  final map = <String, String?>{};
  String? currentUserMessageId;

  for (final message in messages) {
    if (message.user == ChatUser.user) {
      currentUserMessageId = message.id;
    } else {
      final runId = currentUserMessageId != null
          ? messageStates[currentUserMessageId]?.runId
          : null;
      map[message.id] = runId;
    }
  }

  return map;
}
