import 'package:soliplex_agent/soliplex_agent.dart' hide State;
import 'package:soliplex_client/soliplex_client.dart';

import 'quiz_session.dart';

class QuizSessionController {
  QuizSessionController({
    required SoliplexApi api,
    required this.roomId,
    required this.quizId,
  }) : _api = api;

  final SoliplexApi _api;
  final String roomId;
  final String quizId;

  final Signal<QuizSession> session =
      Signal<QuizSession>(const QuizNotStarted());
  final Signal<String?> submissionError = Signal<String?>(null);

  bool _isDisposed = false;

  void start(Quiz quiz) {
    if (!quiz.hasQuestions) {
      throw ArgumentError.value(
        quiz,
        'quiz',
        'Quiz must have at least one question',
      );
    }
    session.value = QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
  }

  void updateInput(QuizInput input) {
    final current = session.value;
    if (current is! QuizInProgress) return;
    if (current.questionState is Submitting ||
        current.questionState is Answered) {
      return;
    }
    submissionError.value = null;
    session.value = current.copyWith(questionState: Composing(input));
  }

  void clearInput() {
    final current = session.value;
    if (current is! QuizInProgress) return;
    if (current.questionState is! Composing) return;
    session.value = current.copyWith(questionState: const AwaitingInput());
  }

  Future<void> submitAnswer() async {
    final current = session.value;
    if (current is! QuizInProgress) return;
    final questionState = current.questionState;
    if (questionState is! Composing || !questionState.canSubmit) return;

    final input = questionState.input;
    session.value = current.copyWith(questionState: Submitting(input));

    try {
      final result = await _api.submitQuizAnswer(
        roomId,
        current.quiz.id,
        current.currentQuestion.id,
        input.answerText,
      );
      if (_isDisposed) return;

      final afterState = session.value;
      if (afterState is! QuizInProgress) return;

      final newResults = {
        ...afterState.results,
        afterState.currentQuestion.id: result,
      };
      session.value = afterState.copyWith(
        results: newResults,
        questionState: Answered(input, result),
      );
    } catch (e) {
      if (_isDisposed) return;
      final afterState = session.value;
      if (afterState is! QuizInProgress) return;
      session.value = afterState.copyWith(questionState: Composing(input));
      submissionError.value = '$e';
    }
  }

  void nextQuestion() {
    final current = session.value;
    if (current is! QuizInProgress) return;
    if (current.questionState is! Answered) return;

    if (current.isLastQuestion) {
      session.value = QuizCompleted(
        quiz: current.quiz,
        results: current.results,
      );
    } else {
      session.value = current.copyWith(
        currentIndex: current.currentIndex + 1,
        questionState: const AwaitingInput(),
      );
    }
  }

  void reset() {
    session.value = const QuizNotStarted();
    submissionError.value = null;
  }

  void retake() {
    final current = session.value;
    final quiz = switch (current) {
      QuizInProgress(:final quiz) => quiz,
      QuizCompleted(:final quiz) => quiz,
      QuizNotStarted() => throw StateError('Cannot retake unstarted quiz'),
    };
    session.value = QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
    submissionError.value = null;
  }

  void dispose() {
    _isDisposed = true;
    session.dispose();
    submissionError.dispose();
  }
}
