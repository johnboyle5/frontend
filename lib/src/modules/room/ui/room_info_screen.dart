import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide State;
import 'package:soliplex_client/soliplex_client.dart' hide Room, State;

import '../../../shared/copy_button.dart';
import '../../../shared/file_type_icons.dart';
import '../../auth/server_entry.dart';

class RoomInfoScreen extends StatefulWidget {
  const RoomInfoScreen({
    super.key,
    required this.serverEntry,
    required this.roomId,
    required this.toolRegistryResolver,
  });

  final ServerEntry serverEntry;
  final String roomId;
  final Future<ToolRegistry> Function(String roomId) toolRegistryResolver;

  @override
  State<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends State<RoomInfoScreen> {
  late CancelToken _cancelToken;
  late Future<Room> _roomFuture;
  late Future<List<RagDocument>> _documentsFuture;
  late Future<List<Tool>> _clientToolsFuture;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    final api = widget.serverEntry.connection.api;
    _roomFuture = api.getRoom(widget.roomId, cancelToken: _cancelToken);
    _documentsFuture =
        api.getDocuments(widget.roomId, cancelToken: _cancelToken)..ignore();
    _clientToolsFuture = widget
        .toolRegistryResolver(widget.roomId)
        .then((r) => r.toolDefinitions);
  }

  @override
  void dispose() {
    _cancelToken.cancel('disposed');
    super.dispose();
  }

  void _retryDocuments() {
    setState(() {
      _cancelToken.cancel('retry');
      _cancelToken = CancelToken();
      _documentsFuture = widget.serverEntry.connection.api
          .getDocuments(widget.roomId, cancelToken: _cancelToken)
        ..ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                '/room/${widget.serverEntry.alias}/${widget.roomId}',
              );
            }
          },
        ),
        title: const Text('Room Information'),
      ),
      body: FutureBuilder<Room>(
        future: _roomFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load room'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Room not found'));
          }
          return _RoomInfoBody(
            room: snapshot.data!,
            api: widget.serverEntry.connection.api,
            roomId: widget.roomId,
            documentsFuture: _documentsFuture,
            clientToolsFuture: _clientToolsFuture,
            onRetryDocuments: _retryDocuments,
          );
        },
      ),
    );
  }
}

class _RoomInfoBody extends StatelessWidget {
  const _RoomInfoBody({
    required this.room,
    required this.api,
    required this.roomId,
    required this.documentsFuture,
    required this.clientToolsFuture,
    required this.onRetryDocuments,
  });

  final Room room;
  final SoliplexApi api;
  final String roomId;
  final Future<List<RagDocument>> documentsFuture;
  final Future<List<Tool>> clientToolsFuture;
  final VoidCallback onRetryDocuments;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (room.hasDescription)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                room.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          _AgentCard(agent: room.agent),
          _FeaturesCard(room: room, api: api, roomId: roomId),
          _ExpandableListCard<MapEntry<String, RoomSkill>>(
            key: const ValueKey('skills'),
            title: 'SKILLS',
            items: room.skills.entries.toList(),
            nameOf: (e) => e.key,
            contentOf: (e) => _buildSkillContent(e.value),
          ),
          _ExpandableListCard<MapEntry<String, RoomTool>>(
            key: const ValueKey('tools'),
            title: 'TOOLS',
            items: room.tools.entries.toList(),
            nameOf: (e) => e.key,
            contentOf: (e) => _buildToolContent(e.value),
          ),
          _ExpandableListCard<MapEntry<String, McpClientToolset>>(
            key: const ValueKey('mcp-toolsets'),
            title: 'MCP CLIENT TOOLSETS',
            emptyLabel: 'MCP client toolsets',
            items: room.mcpClientToolsets.entries.toList(),
            nameOf: (e) => e.key,
            contentOf: (e) => _buildToolsetContent(e.value),
          ),
          _ClientToolsCard(clientToolsFuture: clientToolsFuture),
          _DocumentsCard(
            documentsFuture: documentsFuture,
            onRetry: onRetryDocuments,
          ),
        ],
      ),
    );
  }
}

Widget _buildToolContent(RoomTool tool) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoRow(label: 'Kind', value: tool.kind),
      if (tool.description.isNotEmpty)
        _InfoRow(label: 'Description', value: tool.description),
      if (tool.allowMcp) const _InfoRow(label: 'Allow MCP', value: 'Yes'),
      if (tool.toolRequires.isNotEmpty)
        _InfoRow(label: 'Requires', value: tool.toolRequires),
      if (tool.aguiFeatureNames.isNotEmpty)
        _InfoRow(
          label: 'AG-UI Features',
          value: tool.aguiFeatureNames.join(', '),
        ),
    ],
  );
}

Widget _buildToolsetContent(McpClientToolset toolset) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoRow(label: 'Kind', value: toolset.kind),
      if (toolset.allowedTools != null)
        _InfoRow(
          label: 'Allowed Tools',
          value: toolset.allowedTools!.join(', '),
        ),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});
  final RoomAgent? agent;

  @override
  Widget build(BuildContext context) {
    final agent = this.agent;
    if (agent == null) {
      return const _SectionCard(
        title: 'AGENT',
        children: [_EmptyMessage(label: 'agent')],
      );
    }
    return _SectionCard(
      title: 'AGENT',
      children: [
        _InfoRow(label: 'Model', value: agent.displayModelName),
        ...switch (agent) {
          DefaultRoomAgent(
            :final providerType,
            :final retries,
            :final systemPrompt,
          ) =>
            [
              _InfoRow(label: 'Provider', value: providerType),
              _InfoRow(label: 'Retries', value: '$retries'),
              if (systemPrompt != null)
                _SystemPromptViewer(prompt: systemPrompt),
            ],
          FactoryRoomAgent(:final extraConfig) when extraConfig.isNotEmpty => [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extra Config',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _formatDynamicValue(
                      extraConfig,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          _ => <Widget>[],
        },
        if (agent.aguiFeatureNames.isNotEmpty)
          _InfoRow(
            label: 'AG-UI Features',
            value: agent.aguiFeatureNames.join(', '),
          ),
      ],
    );
  }
}

class _SystemPromptViewer extends StatefulWidget {
  const _SystemPromptViewer({required this.prompt});
  final String prompt;

  @override
  State<_SystemPromptViewer> createState() => _SystemPromptViewerState();
}

class _SystemPromptViewerState extends State<_SystemPromptViewer> {
  bool _expanded = false;

  static const _collapsedMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'System Prompt',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              CopyButton(
                iconSize: 18,
                text: widget.prompt,
                tooltip: 'Copy system prompt',
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final promptStyle = theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 14,
              );
              const containerPadding = 16.0;
              final overflows = !_expanded &&
                  (TextPainter(
                    text: TextSpan(
                      text: widget.prompt,
                      style: promptStyle,
                    ),
                    maxLines: _collapsedMaxLines,
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(
                          maxWidth: constraints.maxWidth - containerPadding,
                        ))
                      .didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      widget.prompt,
                      maxLines: _expanded ? null : _collapsedMaxLines,
                      style: promptStyle,
                    ),
                  ),
                  if (overflows || _expanded)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? 'Collapse' : 'Expand'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({
    required this.room,
    required this.api,
    required this.roomId,
  });

  final Room room;
  final SoliplexApi api;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'FEATURES',
      children: [
        _InfoRow(
          label: 'Attachments',
          value: room.enableAttachments ? 'Enabled' : 'Disabled',
        ),
        _InfoRow(
          label: 'Allow MCP',
          value: room.allowMcp ? 'Yes' : 'No',
        ),
        if (room.allowMcp) _McpTokenRow(api: api, roomId: roomId),
        if (room.aguiFeatureNames.isNotEmpty)
          _InfoRow(
            label: 'AG-UI Features',
            value: room.aguiFeatureNames.join(', '),
          ),
      ],
    );
  }
}

class _McpTokenRow extends StatefulWidget {
  const _McpTokenRow({required this.api, required this.roomId});
  final SoliplexApi api;
  final String roomId;

  @override
  State<_McpTokenRow> createState() => _McpTokenRowState();
}

enum _TokenCopyState { idle, success, error }

class _McpTokenRowState extends State<_McpTokenRow> {
  Future<String>? _tokenFuture;
  _TokenCopyState _copyState = _TokenCopyState.idle;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _tokenFuture = widget.api.getMcpToken(widget.roomId);
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyToken(String token) async {
    try {
      await Clipboard.setData(ClipboardData(text: token));
    } on PlatformException catch (e, st) {
      debugPrint('Clipboard.setData PlatformException: $e\n$st');
      _showCopyFeedback(_TokenCopyState.error);
      return;
    } on Exception catch (e, st) {
      debugPrint('Clipboard.setData failed: $e\n$st');
      _showCopyFeedback(_TokenCopyState.error);
      return;
    }
    _showCopyFeedback(_TokenCopyState.success);
  }

  void _showCopyFeedback(_TokenCopyState value) {
    if (!mounted) return;
    setState(() => _copyState = value);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copyState = _TokenCopyState.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry token'),
              onPressed: () => setState(() {
                _tokenFuture = widget.api.getMcpToken(widget.roomId);
              }),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final token = snapshot.data!;
        final (icon, label) = switch (_copyState) {
          _TokenCopyState.idle => (Icons.copy, 'Copy Token'),
          _TokenCopyState.success => (Icons.check, 'Copied'),
          _TokenCopyState.error => (Icons.error_outline, 'Copy failed'),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: OutlinedButton.icon(
            icon: Icon(icon, size: 16),
            label: Text(label),
            onPressed: _copyState == _TokenCopyState.idle
                ? () => _copyToken(token)
                : null,
          ),
        );
      },
    );
  }
}

class _ExpandableTile extends StatelessWidget {
  const _ExpandableTile({
    required this.name,
    required this.expanded,
    required this.onToggle,
    this.content,
  });

  final String name;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = content != null;

    final nameRow = Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (hasContent)
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );

    return GestureDetector(
      onTap: hasContent ? onToggle : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            nameRow,
            if (expanded && hasContent)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: content,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableListCard<T> extends StatefulWidget {
  const _ExpandableListCard({
    required this.title,
    required this.items,
    required this.nameOf,
    required this.contentOf,
    this.emptyLabel,
    super.key,
  });

  final String title;
  final List<T> items;
  final String Function(T) nameOf;
  final Widget? Function(T) contentOf;
  final String? emptyLabel;

  @override
  State<_ExpandableListCard<T>> createState() => _ExpandableListCardState<T>();
}

class _ExpandableListCardState<T> extends State<_ExpandableListCard<T>> {
  final _expandedNames = <String>{};

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return _SectionCard(
      title: '${widget.title} (${items.length})',
      children: items.isEmpty
          ? [
              _EmptyMessage(
                label: widget.emptyLabel ?? widget.title.toLowerCase(),
              ),
            ]
          : [
              for (final item in items)
                () {
                  final name = widget.nameOf(item);
                  return _ExpandableTile(
                    name: name,
                    expanded: _expandedNames.contains(name),
                    onToggle: () => setState(() {
                      if (!_expandedNames.remove(name)) {
                        _expandedNames.add(name);
                      }
                    }),
                    content: widget.contentOf(item),
                  );
                }(),
            ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'No $label in this room.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ClientToolsCard extends StatelessWidget {
  const _ClientToolsCard({required this.clientToolsFuture});
  final Future<List<Tool>> clientToolsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tool>>(
      future: clientToolsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionCard(
            title: 'CLIENT TOOLS',
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return const _SectionCard(
            title: 'CLIENT TOOLS',
            children: [_EmptyMessage(label: 'client tools')],
          );
        }
        final tools = snapshot.data ?? const [];
        if (tools.isEmpty) {
          return _SectionCard(
            title: 'CLIENT TOOLS (${tools.length})',
            children: const [_EmptyMessage(label: 'client tools')],
          );
        }
        return _ExpandableListCard<Tool>(
          key: const ValueKey('client-tools'),
          title: 'CLIENT TOOLS',
          items: tools,
          nameOf: (t) => t.name,
          contentOf: (t) =>
              t.description.isNotEmpty ? Text(t.description) : null,
        );
      },
    );
  }
}

const _jsonEncoder = JsonEncoder.withIndent('  ');

/// Formats a dynamic value for display, using pretty-printed JSON for
/// complex values (maps/lists) and plain text for scalars.
SelectableText _formatDynamicValue(Object? value, {TextStyle? style}) {
  final isComplex = value is Map || value is Iterable;
  String text;
  if (isComplex) {
    try {
      text = _jsonEncoder.convert(value);
    } catch (_) {
      text = value.toString();
    }
  } else {
    text = '$value';
  }
  return SelectableText(
    text,
    style: isComplex ? style?.copyWith(fontFamily: 'monospace') : style,
  );
}

Widget _buildSkillContent(RoomSkill skill) {
  return _SkillContentColumn(skill: skill);
}

class _SkillContentColumn extends StatelessWidget {
  const _SkillContentColumn({required this.skill});
  final RoomSkill skill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall;
    final noneStyle = theme.textTheme.bodySmall?.copyWith(
      fontStyle: FontStyle.italic,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );

    Widget field(String label, String? value) {
      final isNone = value == null || value.isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 2),
          Text(
            isNone ? 'None' : value,
            style: isNone ? noneStyle : valueStyle,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field('description', skill.description),
        const SizedBox(height: 8),
        field('source', skill.source),
        const SizedBox(height: 8),
        field('license', skill.license),
        const SizedBox(height: 8),
        field('compatibility', skill.compatibility),
        const SizedBox(height: 8),
        field('allowed_tools', skill.allowedTools?.join(', ')),
        const SizedBox(height: 8),
        field('state_namespace', skill.stateNamespace),
        if (skill.metadata.isNotEmpty ||
            (skill.stateTypeSchema?.isNotEmpty ?? false))
          _DialogButton(
            label: 'Show more',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _SkillDetailDialog(skill: skill),
            ),
          ),
      ],
    );
  }
}

class _SkillDetailDialog extends StatelessWidget {
  const _SkillDetailDialog({required this.skill});
  final RoomSkill skill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall;
    final noneStyle = theme.textTheme.bodySmall?.copyWith(
      fontStyle: FontStyle.italic,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );

    Widget mapSection(String title, Map<String, dynamic>? data) {
      final isEmpty = data == null || data.isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: sectionStyle),
          const SizedBox(height: 8),
          if (isEmpty)
            Text('Empty', style: noneStyle)
          else
            for (final entry in data.entries) ...[
              SizedBox(
                width: double.infinity,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: labelStyle),
                        const SizedBox(height: 2),
                        _formatDynamicValue(
                          entry.value,
                          style: valueStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      );
    }

    return AlertDialog(
      title: Text(
        skill.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mapSection('Metadata', skill.metadata),
              const SizedBox(height: 16),
              mapSection('State Schema', skill.stateTypeSchema),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          textStyle: theme.textTheme.labelSmall,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _DocumentsCard extends StatefulWidget {
  const _DocumentsCard({
    required this.documentsFuture,
    required this.onRetry,
  });

  final Future<List<RagDocument>> documentsFuture;
  final VoidCallback onRetry;

  @override
  State<_DocumentsCard> createState() => _DocumentsCardState();
}

class _DocumentsCardState extends State<_DocumentsCard> {
  static const _maxHeight = 550.0;
  static const _shrinkWrapThreshold = 50;

  final _expandedIds = <String>{};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RagDocument> _filterDocs(List<RagDocument> docs) {
    if (_searchQuery.isEmpty) return docs;
    final query = _searchQuery.toLowerCase();
    return docs
        .where(
          (d) => documentDisplayName(d).toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<RagDocument>>(
      future: widget.documentsFuture,
      builder: (context, snapshot) {
        final String title;
        final List<Widget> children;

        if (snapshot.connectionState == ConnectionState.waiting) {
          title = 'DOCUMENTS';
          children = [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ];
        } else if (snapshot.hasError) {
          title = 'DOCUMENTS';
          children = [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load documents',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                FilledButton(
                  onPressed: widget.onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ];
        } else {
          final docs = snapshot.data ?? const [];
          if (docs.isEmpty) {
            title = 'DOCUMENTS (0)';
            children = [
              Text(
                'No documents in this room.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ];
          } else {
            final filtered = _filterDocs(docs);
            title = _searchQuery.isEmpty
                ? 'DOCUMENTS (${docs.length})'
                : 'DOCUMENTS (${filtered.length} / ${docs.length})';
            children = [
              if (docs.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear search',
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                            )
                          : null,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _maxHeight),
                child: ListView.builder(
                  shrinkWrap: filtered.length <= _shrinkWrapThreshold,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final expanded = _expandedIds.contains(doc.id);
                    return _buildDocTile(doc, expanded, theme);
                  },
                ),
              ),
            ];
          }
        }

        return _SectionCard(
          title: title,
          children: children,
        );
      },
    );
  }

  Widget _buildDocTile(
    RagDocument doc,
    bool expanded,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        if (expanded) {
          _expandedIds.remove(doc.id);
        } else {
          _expandedIds.add(doc.id);
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  getFileTypeIcon(documentIconPath(doc)),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    documentDisplayName(doc),
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (expanded) _buildDocMetadata(doc),
          ],
        ),
      ),
    );
  }

  Widget _buildDocMetadata(RagDocument doc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall;

    final dateFields = <(String, String)>[];
    if (doc.createdAt != null) {
      dateFields.add(('created_at', _formatDateTime(doc.createdAt!)));
    }
    if (doc.updatedAt != null) {
      dateFields.add(('updated_at', _formatDateTime(doc.updatedAt!)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('id', style: labelStyle),
            const SizedBox(height: 2),
            SelectableText(
              doc.id,
              style: valueStyle?.copyWith(fontFamily: 'monospace'),
            ),
            if (doc.uri.isNotEmpty || dateFields.isNotEmpty)
              const SizedBox(height: 8),
            if (doc.uri.isNotEmpty) ...[
              Text('uri', style: labelStyle),
              const SizedBox(height: 2),
              SelectableText(
                doc.uri,
                style: valueStyle?.copyWith(fontFamily: 'monospace'),
              ),
              if (dateFields.isNotEmpty) const SizedBox(height: 8),
            ],
            if (dateFields.isNotEmpty)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final (label, value) in dateFields)
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: labelStyle),
                          const SizedBox(height: 2),
                          SelectableText(
                            value,
                            style: valueStyle,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (doc.metadata.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    textStyle: theme.textTheme.labelSmall,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _MetadataDialog(
                      title: doc.title,
                      metadata: doc.metadata,
                    ),
                  ),
                  child: const Text('Show metadata'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetadataDialog extends StatelessWidget {
  const _MetadataDialog({
    required this.title,
    required this.metadata,
  });

  final String title;
  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entries = metadata.entries.toList();

    return AlertDialog(
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries) ...[
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _formatDynamicValue(
                            entry.value,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (entry.key != entries.last.key) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
