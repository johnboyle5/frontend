import 'package:soliplex_client/src/application/streaming_state.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:soliplex_client/src/domain/conversation.dart';

/// Outcome of [synthesizeNoResponseIfNeeded]. The explicit `synthesized`
/// flag removes the by-reference `identical(...)` check callers used to
/// need to distinguish "appended a tile" from "declined".
typedef NoResponseSynthesisResult = ({
  Conversation conversation,
  bool synthesized,
});

/// Single source of truth for synthesized no-response message ids;
/// synthesis, tracker rekeying, and historical replay must derive ids
/// through this helper so they agree for the same run.
String noResponseMessageId(String runId) => '$_noResponseIdPrefix$runId';

/// Single source of truth for ids of `ErrorMessage`s synthesized when
/// `_processRunError` falls back from `NoResponseTile` synthesis (no
/// buffered thinking or unresolved tool calls).
String runErrorMessageId(String runId) => '$_runErrorIdPrefix$runId';

const _noResponseIdPrefix = 'no-response-';
const _runErrorIdPrefix = 'run-error-';

/// Appends a synthesized [NoResponseTile] to [conversation] when a run has
/// reached a terminal state with buffered thinking but no assistant
/// `TextMessageStart` / `Content` / `End` for an actual reply.
///
/// Declines (returning the input conversation and `synthesized: false`) when:
/// - [streaming] is not [AwaitingText] (a reply was in progress).
/// - The buffered thinking text is empty (no model output to preserve).
/// - The conversation has any tool call with status `pending`, `streaming`,
///   or `executing` (the run is yielding to client tools — the tool call
///   IS the response, not a missing one).
///
/// Otherwise appends a [NoResponseTile] carrying [reason] and the buffered
/// thinking so downstream UI can render the muted "Run
/// finished/failed/cancelled without a response" tile, optionally with the
/// backend error message for the `failed` case.
NoResponseSynthesisResult synthesizeNoResponseIfNeeded({
  required Conversation conversation,
  required StreamingState streaming,
  required String runId,
  required TerminalReason reason,
  String? terminalErrorDetail,
}) {
  assert(
    (reason == TerminalReason.failed) == (terminalErrorDetail != null),
    'terminalErrorDetail is required iff reason is TerminalReason.failed',
  );
  if (streaming is! AwaitingText ||
      streaming.bufferedThinkingText.isEmpty ||
      _hasUnresolvedToolCalls(conversation)) {
    return (conversation: conversation, synthesized: false);
  }

  final tile = switch (reason) {
    TerminalReason.failed => NoResponseTile.failed(
        id: noResponseMessageId(runId),
        thinkingText: streaming.bufferedThinkingText,
        errorDetail: terminalErrorDetail!,
      ),
    TerminalReason.cancelled => NoResponseTile.cancelled(
        id: noResponseMessageId(runId),
        thinkingText: streaming.bufferedThinkingText,
      ),
    TerminalReason.finished => NoResponseTile.finished(
        id: noResponseMessageId(runId),
        thinkingText: streaming.bufferedThinkingText,
      ),
  };
  return (
    conversation: conversation.withAppendedMessage(tile),
    synthesized: true,
  );
}

bool _hasUnresolvedToolCalls(Conversation conversation) {
  for (final tc in conversation.toolCalls) {
    if (tc.status == ToolCallStatus.pending ||
        tc.status == ToolCallStatus.streaming ||
        tc.status == ToolCallStatus.executing) {
      return true;
    }
  }
  return false;
}
