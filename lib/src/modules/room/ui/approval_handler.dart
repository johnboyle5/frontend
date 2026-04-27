import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide State;

import '../human_approval_extension.dart';

/// Zero-size widget that subscribes to a [pendingApproval] signal and
/// shows an approval dialog when a tool requests user consent.
///
/// Place inside a [Stack] alongside the rest of the chat UI.
class ApprovalHandler extends StatefulWidget {
  const ApprovalHandler({
    super.key,
    required this.pendingApproval,
    required this.onRespond,
  });

  final ReadonlySignal<ApprovalRequest?> pendingApproval;
  final void Function(bool approved) onRespond;

  @override
  State<ApprovalHandler> createState() => _ApprovalHandlerState();
}

class _ApprovalHandlerState extends State<ApprovalHandler> {
  void Function()? _unsub;
  ApprovalRequest? _showing;

  @override
  void initState() {
    super.initState();
    _unsub = widget.pendingApproval.subscribe(_onChange);
  }

  @override
  void didUpdateWidget(covariant ApprovalHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pendingApproval, widget.pendingApproval)) {
      _unsub?.call();
      _showing = null;
      _unsub = widget.pendingApproval.subscribe(_onChange);
    }
  }

  void _onChange(ApprovalRequest? request) {
    if (request == null || identical(request, _showing)) return;
    _showing = request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _show(request);
    });
  }

  Future<void> _show(ApprovalRequest request) async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApprovalDialog(request: request),
    );
    if (!mounted) return;
    widget.onRespond(approved ?? false);
    _showing = null;
  }

  @override
  void dispose() {
    _unsub?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Dialog that prompts the user to approve or deny a pending tool call.
class ApprovalDialog extends StatelessWidget {
  const ApprovalDialog({super.key, required this.request});

  final ApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Tool Approval Required'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.toolName,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(request.rationale, style: theme.textTheme.bodyMedium),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
