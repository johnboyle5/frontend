import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/src/modules/quiz/ui/quiz_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_server_entry.dart';

void main() {
  late FakeSoliplexApi api;

  setUp(() {
    api = FakeSoliplexApi();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: QuizScreen(
        serverEntry: createTestServerEntry(api: api),
        roomId: 'room-1',
        quizId: 'quiz-1',
      ),
    );
  }

  testWidgets('shows loading then quiz title', (tester) async {
    api.nextQuiz = Quiz(
      id: 'quiz-1',
      title: 'Intro to ML',
      questions: const [
        QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
      ],
    );
    await tester.pumpWidget(buildScreen());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Intro to ML'), findsNWidgets(2));
    expect(find.text('Start Quiz'), findsOneWidget);
  });

  testWidgets('shows error with retry on fetch failure', (tester) async {
    api.nextQuizError = Exception('fetch failed');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('fetch failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows Back to Room on 404', (tester) async {
    api.nextQuizError = NotFoundException(message: 'quiz not found');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('Back to Room'), findsOneWidget);
  });
}
