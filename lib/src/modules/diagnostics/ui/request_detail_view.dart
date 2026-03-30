import 'package:flutter/material.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide State;

import '../../../shared/copy_button.dart';
import '../models/format_utils.dart';
import '../models/http_event_group.dart';
import 'http_status_display.dart';

/// Displays detailed request/response information in a tabbed view.
///
/// Tabs:
/// - Request: Method, URL, headers, body
/// - Response: Status, headers, body
/// - curl: Generated curl command for reproduction
class RequestDetailView extends StatelessWidget {
  const RequestDetailView({required this.group, super.key});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildSummaryHeader(context),
          const TabBar(
            tabs: [
              Tab(text: 'Request'),
              Tab(text: 'Response'),
              Tab(text: 'curl'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestTab(group: group),
                _ResponseTab(group: group),
                _CurlTab(group: group),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MethodBadge(
                method: group.methodLabel,
                isStream: group.isStream,
              ),
              const SizedBox(width: 8),
              Expanded(child: HttpStatusDisplay(group: group)),
              Text(
                group.timestamp.toHttpTimeString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            group.uri.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method, required this.isStream});

  final String method;
  final bool isStream;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isStream
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;
    final textColor = isStream
        ? colorScheme.onSecondaryContainer
        : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}

class _RequestTab extends StatelessWidget {
  const _RequestTab({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    final headers = group.requestHeaders;
    final body = group.requestBody;

    if (headers.isEmpty && body == null) {
      return const _EmptyTabContent(message: 'No request headers or body');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (headers.isNotEmpty) ...[
          _SectionHeader(
            title: 'Headers',
            copyButton: CopyButton(
              iconSize: 18,
              text:
                  headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              tooltip: 'Copy Headers',
            ),
          ),
          _HeadersTable(headers: headers),
          const SizedBox(height: 16),
        ],
        if (body != null) ...[
          _SectionHeader(
            title: 'Body',
            copyButton: CopyButton(
              iconSize: 18,
              text: HttpEventGroup.formatBody(body),
              tooltip: 'Copy Body',
            ),
          ),
          _BodyDisplay(body: body),
        ],
      ],
    );
  }
}

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.isStream) {
      return _buildStreamResponse(context);
    }

    final response = group.response;
    final error = group.error;

    if (response == null && error == null) {
      return const _EmptyTabContent(message: 'Waiting for response...');
    }

    if (error != null) {
      return _buildErrorResponse(error);
    }

    return _buildNormalResponse(response!);
  }

  Widget _buildStreamResponse(BuildContext context) {
    final streamEnd = group.streamEnd;
    if (streamEnd == null) {
      return const _EmptyTabContent(message: 'Stream in progress...');
    }

    if (streamEnd.error != null) {
      return _ErrorDisplay(
        message: streamEnd.error!.message,
        details: 'Duration: ${streamEnd.duration.toHttpDurationString()}\n'
            'Bytes received: ${streamEnd.bytesReceived.toHttpBytesString()}',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetadataRow(
          label: 'Duration',
          value: streamEnd.duration.toHttpDurationString(),
        ),
        _MetadataRow(
          label: 'Bytes Received',
          value: streamEnd.bytesReceived.toHttpBytesString(),
        ),
        if (streamEnd.body != null) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Stream Content',
            copyButton: CopyButton(
              iconSize: 18,
              text: streamEnd.body!,
              tooltip: 'Copy Stream Content',
            ),
          ),
          _BodyDisplay(body: streamEnd.body),
        ],
      ],
    );
  }

  Widget _buildErrorResponse(HttpErrorEvent error) {
    return _ErrorDisplay(
      message: error.exception.message,
      details: 'Type: ${error.exception.runtimeType}\n'
          'Duration: ${error.duration.toHttpDurationString()}',
    );
  }

  Widget _buildNormalResponse(HttpResponseEvent resp) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetadataRow(label: 'Status', value: '${resp.statusCode}'),
        if (resp.reasonPhrase != null)
          _MetadataRow(label: 'Reason', value: resp.reasonPhrase!),
        _MetadataRow(
          label: 'Duration',
          value: resp.duration.toHttpDurationString(),
        ),
        _MetadataRow(
          label: 'Size',
          value: resp.bodySize.toHttpBytesString(),
        ),
        if (resp.headers != null && resp.headers!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Headers',
            copyButton: CopyButton(
              iconSize: 18,
              text: resp.headers!.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
              tooltip: 'Copy Headers',
            ),
          ),
          _HeadersTable(headers: resp.headers!),
        ],
        if (resp.body != null) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Body',
            copyButton: CopyButton(
              iconSize: 18,
              text: HttpEventGroup.formatBody(resp.body),
              tooltip: 'Copy Body',
            ),
          ),
          _BodyDisplay(body: resp.body),
        ],
      ],
    );
  }
}

class _CurlTab extends StatelessWidget {
  const _CurlTab({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    final curl = group.toCurl();
    if (curl == null) {
      return const _EmptyTabContent(
        message: 'curl command unavailable - no request data',
      );
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'curl command',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              CopyButton(
                  iconSize: 18, text: curl, tooltip: 'Copy to clipboard'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                curl,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.copyButton});

  final String title;
  final Widget? copyButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const Spacer(),
          if (copyButton != null) copyButton!,
        ],
      ),
    );
  }
}

class _HeadersTable extends StatelessWidget {
  const _HeadersTable({required this.headers});

  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          for (final (index, entry) in headers.entries.indexed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: index.isEven
                    ? colorScheme.surfaceContainerLow
                    : colorScheme.surface,
                border: index > 0
                    ? Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: SelectableText(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      entry.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BodyDisplay extends StatelessWidget {
  const _BodyDisplay({required this.body});

  final dynamic body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedBody = HttpEventGroup.formatBody(body);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        formattedBody,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTabContent extends StatelessWidget {
  const _EmptyTabContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({required this.message, this.details});

  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
