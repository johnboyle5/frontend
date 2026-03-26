import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'package:soliplex_frontend/src/modules/room/run_id_resolver.dart';

void main() {
  test('maps assistant message to preceding user message runId', () {
    final messages = <ChatMessage>[
      TextMessage(
        id: 'user-1',
        user: ChatUser.user,
        createdAt: DateTime(2026),
        text: 'Hello',
      ),
      TextMessage(
        id: 'asst-1',
        user: ChatUser.assistant,
        createdAt: DateTime(2026),
        text: 'Hi there',
      ),
    ];
    final messageStates = {
      'user-1': MessageState(
        userMessageId: 'user-1',
        sourceReferences: const [],
        runId: 'run-1',
      ),
    };

    final map = buildRunIdMap(messages, messageStates);
    expect(map['asst-1'], 'run-1');
    expect(map['user-1'], isNull);
  });

  test('multiple assistant messages share same runId', () {
    final messages = <ChatMessage>[
      TextMessage(
        id: 'user-1',
        user: ChatUser.user,
        createdAt: DateTime(2026),
        text: 'Hello',
      ),
      ToolCallMessage(
        id: 'tool-1',
        createdAt: DateTime(2026),
        toolCalls: const [],
      ),
      TextMessage(
        id: 'asst-1',
        user: ChatUser.assistant,
        createdAt: DateTime(2026),
        text: 'Done',
      ),
    ];
    final messageStates = {
      'user-1': MessageState(
        userMessageId: 'user-1',
        sourceReferences: const [],
        runId: 'run-1',
      ),
    };

    final map = buildRunIdMap(messages, messageStates);
    expect(map['tool-1'], 'run-1');
    expect(map['asst-1'], 'run-1');
  });

  test('returns null for messages with no preceding user message', () {
    final messages = <ChatMessage>[
      TextMessage(
        id: 'asst-1',
        user: ChatUser.assistant,
        createdAt: DateTime(2026),
        text: 'Welcome',
      ),
    ];

    final map = buildRunIdMap(messages, const {});
    expect(map['asst-1'], isNull);
  });
}
