import 'package:soliplex_client/src/application/streaming_state.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:soliplex_client/src/domain/conversation.dart';

/// Id of the synthesized "no-response" assistant `TextMessage` for [runId].
/// Synthesis, tracker rekeying, and historical replay all derive ids
/// through this helper so they agree on the same id for the same run.
String noResponseMessageId(String runId) => '$_noResponseIdPrefix$runId';

const _noResponseIdPrefix = 'no-response-';

/// Appends a synthesized "no response" `TextMessage` to [conversation]
/// when a run has reached a terminal state with buffered thinking but no
/// assistant `TextMessageStart` / `Content` / `End` for an actual reply.
///
/// Returns [conversation] unchanged when:
/// - [streaming] is not [AwaitingText] (a reply was in progress).
/// - The buffered thinking text is empty (no model output to preserve).
/// - The conversation has any tool call with status `pending` or
///   `streaming` (the run is yielding to client tools — the tool call
///   IS the response, not a missing one).
///
/// Otherwise appends `TextMessage(text: '', thinkingText: <buffered>,
/// terminalReason: [reason], terminalErrorDetail: [terminalErrorDetail])`
/// so downstream UI can render the muted
/// "Run finished/failed/cancelled without a response" tile, optionally
/// carrying the backend error message for the `failed` case.
Conversation synthesizeNoResponseIfNeeded({
  required Conversation conversation,
  required StreamingState streaming,
  required String runId,
  required TerminalReason reason,
  String? terminalErrorDetail,
}) {
  if (streaming is! AwaitingText) return conversation;
  if (streaming.bufferedThinkingText.isEmpty) return conversation;
  if (_hasUnresolvedToolCalls(conversation)) return conversation;

  return conversation.withAppendedMessage(
    TextMessage.create(
      id: noResponseMessageId(runId),
      user: ChatUser.assistant,
      text: '',
      thinkingText: streaming.bufferedThinkingText,
      terminalReason: reason,
      terminalErrorDetail: terminalErrorDetail,
    ),
  );
}

bool _hasUnresolvedToolCalls(Conversation conversation) {
  for (final tc in conversation.toolCalls) {
    if (tc.status == ToolCallStatus.pending ||
        tc.status == ToolCallStatus.streaming) {
      return true;
    }
  }
  return false;
}
