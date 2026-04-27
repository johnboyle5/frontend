import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _Approval1 extends ToolApprovalExtension {
  @override
  Future<void> onAttach(AgentSession session) async {}

  @override
  List<ClientTool> get tools => const [];

  @override
  void onDispose() {}

  @override
  Future<bool> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String rationale,
  }) async =>
      true;
}

class _Approval2 extends ToolApprovalExtension {
  @override
  Future<void> onAttach(AgentSession session) async {}

  @override
  List<ClientTool> get tools => const [];

  @override
  void onDispose() {}

  @override
  Future<bool> requestApproval({
    required String toolCallId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String rationale,
  }) async =>
      false;
}

void main() {
  group('ToolApprovalExtension namespace', () {
    test('subclasses share the locked "tool_approval" namespace', () {
      expect(_Approval1().namespace, 'tool_approval');
      expect(_Approval2().namespace, 'tool_approval');
    });

    test(
      'registering two ToolApprovalExtensions logs an error and keeps '
      'first-wins lookup',
      () {
        final logger = _MockLogger();
        final first = _Approval1();
        final second = _Approval2();
        final coordinator = SessionCoordinator(
          [first, second],
          logger: logger,
        );

        verify(
          () => logger.error(
            any(that: contains('tool_approval')),
          ),
        ).called(1);
        expect(coordinator.getExtension<ToolApprovalExtension>(), same(first));
      },
    );
  });
}
