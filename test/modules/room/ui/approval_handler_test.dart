import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_frontend/src/modules/room/human_approval_extension.dart';
import 'package:soliplex_frontend/src/modules/room/ui/approval_handler.dart';

ApprovalRequest _request({String toolCallId = 'tc-1'}) => ApprovalRequest(
      toolCallId: toolCallId,
      toolName: 'send_email',
      arguments: const {'to': 'a@b.c'},
      rationale: 'send a message',
    );

Widget _harness({
  required ReadonlySignal<ApprovalRequest?> pendingApproval,
  required void Function(bool) onRespond,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ApprovalHandler(
          pendingApproval: pendingApproval,
          onRespond: onRespond,
        ),
      ),
    );

void main() {
  testWidgets('shows dialog when signal transitions null → request',
      (tester) async {
    final pending = Signal<ApprovalRequest?>(null);
    final responses = <bool>[];
    await tester.pumpWidget(
      _harness(pendingApproval: pending, onRespond: responses.add),
    );

    expect(find.text('Tool Approval Required'), findsNothing);

    pending.value = _request();
    await tester.pumpAndSettle();

    expect(find.text('Tool Approval Required'), findsOneWidget);
    expect(find.text('send_email'), findsOneWidget);
    expect(find.text('send a message'), findsOneWidget);
  });

  testWidgets('Allow tap forwards true', (tester) async {
    final pending = Signal<ApprovalRequest?>(null);
    final responses = <bool>[];
    await tester.pumpWidget(
      _harness(pendingApproval: pending, onRespond: responses.add),
    );

    pending.value = _request();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(responses, [true]);
    expect(find.text('Tool Approval Required'), findsNothing);
  });

  testWidgets('Deny tap forwards false', (tester) async {
    final pending = Signal<ApprovalRequest?>(null);
    final responses = <bool>[];
    await tester.pumpWidget(
      _harness(pendingApproval: pending, onRespond: responses.add),
    );

    pending.value = _request();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();

    expect(responses, [false]);
  });

  testWidgets('does not stack a second dialog when same request re-emits',
      (tester) async {
    final pending = Signal<ApprovalRequest?>(null);
    final responses = <bool>[];
    await tester.pumpWidget(
      _harness(pendingApproval: pending, onRespond: responses.add),
    );

    final req = _request();
    pending.value = req;
    await tester.pumpAndSettle();

    pending.value = req;
    await tester.pump();

    expect(find.text('Tool Approval Required'), findsOneWidget);
  });

  testWidgets('replaces existing dialog when a different request arrives',
      (tester) async {
    final pending = Signal<ApprovalRequest?>(null);
    final responses = <bool>[];
    await tester.pumpWidget(
      _harness(pendingApproval: pending, onRespond: responses.add),
    );

    pending.value = _request(toolCallId: 'tc-A');
    await tester.pumpAndSettle();
    expect(find.text('Tool Approval Required'), findsOneWidget);

    // A new request supersedes the showing dialog. The extension's
    // auto-deny semantics mean the prior dialog's response is moot, so
    // the UI must drop it and show only the new one.
    pending.value = _request(toolCallId: 'tc-B');
    await tester.pumpAndSettle();

    expect(find.text('Tool Approval Required'), findsOneWidget);
    // No spurious response was forwarded for the superseded request.
    expect(responses, isEmpty);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    // Only the new request's response is forwarded.
    expect(responses, [true]);
    expect(find.text('Tool Approval Required'), findsNothing);
  });
}
