import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide State;

import '../../diagnostics/models/json_tree_model.dart';
import '../../diagnostics/ui/json_tree_view.dart';

/// Renders a [DroppedEventMessage] as a low-emphasis, collapsed-by-default
/// card. Schema-drift events in production should show as a quiet hint,
/// not a wall of warnings.
///
/// Collapsed: a single line `"Couldn't process 1 event ($source)"`.
/// Expanded: source + runId subtitle, plus a [JsonTreeView] for `Map`
/// payloads (raw text for null/non-Map payloads).
class DroppedEventMessageTile extends StatefulWidget {
  const DroppedEventMessageTile({super.key, required this.message});

  final DroppedEventMessage message;

  @override
  State<DroppedEventMessageTile> createState() =>
      _DroppedEventMessageTileState();
}

class _DroppedEventMessageTileState extends State<DroppedEventMessageTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: muted,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 16,
                    color: muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _collapsedLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: muted,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subtitle(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _payload(theme, mono),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _collapsedLabel() {
    return "Couldn't process 1 event (${_humanizeSource(widget.message.source)})";
  }

  String _subtitle() {
    final runId = widget.message.runId;
    final reason = widget.message.reason;
    return runId == null ? reason : 'run $runId — $reason';
  }

  Widget _payload(ThemeData theme, TextStyle? mono) {
    final raw = widget.message.rawPayload;
    if (raw == null) {
      return Text(
        '(payload unavailable)',
        style: mono?.copyWith(fontStyle: FontStyle.italic),
      );
    }
    return JsonTreeView(nodes: buildJsonTree(raw));
  }

  String _humanizeSource(DropSource source) {
    switch (source) {
      case DropSource.decode:
        return 'decode';
      case DropSource.eventProcessing:
        return 'processing';
    }
  }
}
