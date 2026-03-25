import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'package:soliplex_frontend/src/modules/room/ui/streaming_tile.dart';

void main() {
  testWidgets('renders thinking indicator for AwaitingText', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StreamingTile(streamingState: AwaitingText()),
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Thinking...'), findsOneWidget);
  });

  testWidgets('renders streamed text for TextStreaming', (tester) async {
    const streaming = TextStreaming(
      messageId: 'msg-1',
      user: ChatUser.assistant,
      text: 'Hello world',
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StreamingTile(streamingState: streaming),
      ),
    ));

    expect(find.text('Hello world'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders placeholder for empty TextStreaming', (tester) async {
    const streaming = TextStreaming(
      messageId: 'msg-1',
      user: ChatUser.assistant,
      text: '',
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StreamingTile(streamingState: streaming),
      ),
    ));

    expect(find.text('...'), findsOneWidget);
  });
}
