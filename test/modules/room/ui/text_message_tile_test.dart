import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'package:soliplex_frontend/src/modules/room/message_expansions.dart';
import 'package:soliplex_frontend/src/modules/room/room_providers.dart';
import 'package:soliplex_frontend/src/modules/room/ui/copy_button.dart';
import 'package:soliplex_frontend/src/modules/room/ui/feedback_buttons.dart';
import 'package:soliplex_frontend/src/modules/room/ui/text_message_tile.dart';

Widget _wrap(Widget child, {MessageExpansions? store}) => ProviderScope(
      overrides: [
        messageExpansionsProvider
            .overrideWithValue(store ?? MessageExpansions()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('user message shows copy button but no feedback buttons',
      (tester) async {
    await tester.pumpWidget(_wrap(
      TextMessageTile(
        roomId: 'r',
        message: TextMessage(
          id: '1',
          user: ChatUser.user,
          createdAt: DateTime(2026),
          text: 'Hello',
        ),
      ),
    ));

    expect(find.byType(CopyButton), findsOneWidget);
    expect(find.byType(FeedbackButtons), findsNothing);
  });

  testWidgets('assistant message shows copy button and feedback buttons',
      (tester) async {
    await tester.pumpWidget(_wrap(
      TextMessageTile(
        roomId: 'r',
        message: TextMessage(
          id: '2',
          user: ChatUser.assistant,
          createdAt: DateTime(2026),
          text: 'Hi there',
        ),
        runId: 'run-1',
        onFeedbackSubmit: (_, __) {},
      ),
    ));

    expect(find.byType(CopyButton), findsOneWidget);
    expect(find.byType(FeedbackButtons), findsOneWidget);
  });

  testWidgets('assistant message without feedback callback shows only copy',
      (tester) async {
    await tester.pumpWidget(_wrap(
      TextMessageTile(
        roomId: 'r',
        message: TextMessage(
          id: '3',
          user: ChatUser.assistant,
          createdAt: DateTime(2026),
          text: 'Hi there',
        ),
      ),
    ));

    expect(find.byType(CopyButton), findsOneWidget);
    expect(find.byType(FeedbackButtons), findsNothing);
  });

  testWidgets('thinking block shows copy button', (tester) async {
    await tester.pumpWidget(_wrap(
      TextMessageTile(
        roomId: 'r',
        message: TextMessage(
          id: '4',
          user: ChatUser.assistant,
          createdAt: DateTime(2026),
          text: 'Response',
          thinkingText: 'Let me think about this...',
        ),
      ),
    ));

    // One CopyButton for the message, one for the thinking block
    expect(find.byType(CopyButton), findsNWidgets(2));
  });

  testWidgets('fallback thinking block persists expansion across remount',
      (tester) async {
    // Fallback _ThinkingBlock wires ExpansionTile.initiallyExpanded +
    // onExpansionChanged to the store. A remount (which destroys
    // ExpansionTile's internal State) must re-seed from the store.
    final store = MessageExpansions();
    final msg = TextMessage(
      id: 'msg-5',
      user: ChatUser.assistant,
      createdAt: DateTime(2026),
      text: 'Response',
      thinkingText: 'Deep thought',
    );

    Widget tree(Key parentKey) => _wrap(
          KeyedSubtree(
            key: parentKey,
            child: TextMessageTile(roomId: 'r', message: msg),
          ),
          store: store,
        );

    await tester.pumpWidget(tree(const ValueKey('A')));
    expect(find.text('Deep thought'), findsNothing);

    await tester.tap(find.text('Thinking...'));
    await tester.pumpAndSettle();
    expect(find.text('Deep thought'), findsOneWidget);

    await tester.pumpWidget(tree(const ValueKey('B')));
    await tester.pumpAndSettle();
    expect(find.text('Deep thought'), findsOneWidget);
  });

  group('terminal-reason bubble', () {
    TextMessage terminalMessage({
      required TerminalReason reason,
      String? errorDetail,
    }) =>
        TextMessage(
          id: 'no-response-run-1',
          user: ChatUser.assistant,
          createdAt: DateTime(2026),
          text: '',
          thinkingText: 'reasoning',
          terminalReason: reason,
          terminalErrorDetail: errorDetail,
        );

    testWidgets('finished renders "Run finished without a response"',
        (tester) async {
      await tester.pumpWidget(_wrap(
        TextMessageTile(
          roomId: 'r',
          message: terminalMessage(reason: TerminalReason.finished),
        ),
      ));

      expect(find.text('Run finished without a response'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets(
        'failed without detail falls back to '
        '"Run failed without a response"', (tester) async {
      await tester.pumpWidget(_wrap(
        TextMessageTile(
          roomId: 'r',
          message: terminalMessage(reason: TerminalReason.failed),
        ),
      ));

      expect(find.text('Run failed without a response'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('failed with detail renders "Run failed: <error>"',
        (tester) async {
      await tester.pumpWidget(_wrap(
        TextMessageTile(
          roomId: 'r',
          message: terminalMessage(
            reason: TerminalReason.failed,
            errorDetail: 'rate limit exceeded',
          ),
        ),
      ));

      // Backend error must reach the persisted tile (not just the
      // transient send-error banner) so reload still shows the cause.
      expect(find.text('Run failed: rate limit exceeded'), findsOneWidget);
      expect(
        find.text('Run failed without a response'),
        findsNothing,
        reason: 'detail must replace the generic copy, not append to it',
      );
    });

    testWidgets('cancelled renders "Run cancelled without a response"',
        (tester) async {
      await tester.pumpWidget(_wrap(
        TextMessageTile(
          roomId: 'r',
          message: terminalMessage(reason: TerminalReason.cancelled),
        ),
      ));

      expect(find.text('Run cancelled without a response'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('terminalReason: null falls back to the normal bubble',
        (tester) async {
      // Regression guard: the bubble switch must not accidentally render
      // the muted terminal-reason copy on a normal assistant reply.
      await tester.pumpWidget(_wrap(
        TextMessageTile(
          roomId: 'r',
          message: TextMessage(
            id: 'asst-1',
            user: ChatUser.assistant,
            createdAt: DateTime(2026),
            text: 'Real reply',
          ),
        ),
      ));

      expect(find.text('Real reply'), findsOneWidget);
      expect(
        find.textContaining('without a response'),
        findsNothing,
      );
    });
  });

  testWidgets('fallback thinking block persists collapse across remount',
      (tester) async {
    // Mirror of the expand-persists test: collapse (false) must also be
    // written to the store so a remount re-seeds as collapsed.
    final store = MessageExpansions();
    final msg = TextMessage(
      id: 'msg-6',
      user: ChatUser.assistant,
      createdAt: DateTime(2026),
      text: 'Response',
      thinkingText: 'Deep thought',
    );

    Widget tree(Key parentKey) => _wrap(
          KeyedSubtree(
            key: parentKey,
            child: TextMessageTile(roomId: 'r', message: msg),
          ),
          store: store,
        );

    await tester.pumpWidget(tree(const ValueKey('A')));
    await tester.tap(find.text('Thinking...'));
    await tester.pumpAndSettle();
    expect(find.text('Deep thought'), findsOneWidget);

    await tester.tap(find.text('Thinking...'));
    await tester.pumpAndSettle();
    expect(find.text('Deep thought'), findsNothing);
    expect(store.forMessage('r', 'msg-6').thinkingExpanded, isFalse);

    await tester.pumpWidget(tree(const ValueKey('B')));
    await tester.pumpAndSettle();
    expect(find.text('Deep thought'), findsNothing);
  });
}
