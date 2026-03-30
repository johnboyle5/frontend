import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/event_accumulator.dart';
import 'package:soliplex_frontend/src/modules/diagnostics/models/sse_event_parser.dart';

void main() {
  test('full pipeline: SSE body -> parse -> accumulate', () {
    const sseBody =
        'data: {"type":"RUN_STARTED","threadId":"t1","runId":"r1"}\n'
        '\n'
        'data: {"type":"TEXT_MESSAGE_START","messageId":"m1","role":"assistant"}\n'
        'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m1","delta":"Let me "}\n'
        'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m1","delta":"search."}\n'
        'data: {"type":"TEXT_MESSAGE_END","messageId":"m1"}\n'
        '\n'
        'data: {"type":"TOOL_CALL_START","toolCallId":"tc1","toolCallName":"search","parentMessageId":"m1"}\n'
        'data: {"type":"TOOL_CALL_ARGS","toolCallId":"tc1","delta":"{\\"query\\": \\"AG-UI\\"}"}\n'
        'data: {"type":"TOOL_CALL_END","toolCallId":"tc1"}\n'
        'data: {"type":"TOOL_CALL_RESULT","messageId":"m2","toolCallId":"tc1","content":"AG-UI is a protocol.","role":"tool"}\n'
        '\n'
        'data: {"type":"TEXT_MESSAGE_START","messageId":"m3","role":"assistant"}\n'
        'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m3","delta":"Based on my search, AG-UI is a protocol."}\n'
        'data: {"type":"TEXT_MESSAGE_END","messageId":"m3"}\n'
        '\n'
        'data: {"type":"RUN_FINISHED","threadId":"t1","runId":"r1"}\n';

    final parseResult = parseSseEvents(sseBody);
    expect(parseResult.wasTruncated, isFalse);
    expect(parseResult.events, hasLength(13));

    final run = accumulateEvents(parseResult.events);
    expect(run.isComplete, isTrue);

    expect(run.entries, hasLength(6));
    expect(run.entries[0], isA<RunStatusEntry>());
    expect((run.entries[0] as RunStatusEntry).type, 'RUN_STARTED');

    final msg1 = run.entries[1] as MessageEntry;
    expect(msg1.text, 'Let me search.');
    expect(msg1.role, 'assistant');

    final toolCall = run.entries[2] as ToolCallEntry;
    expect(toolCall.toolName, 'search');
    expect(toolCall.args, contains('"query"'));

    final toolResult = run.entries[3] as ToolResultEntry;
    expect(toolResult.content, 'AG-UI is a protocol.');

    final msg2 = run.entries[4] as MessageEntry;
    expect(msg2.text, 'Based on my search, AG-UI is a protocol.');

    expect(run.entries[5], isA<RunStatusEntry>());
    expect((run.entries[5] as RunStatusEntry).type, 'RUN_FINISHED');
  });
}
