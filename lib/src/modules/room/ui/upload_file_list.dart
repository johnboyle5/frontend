import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../upload_tracker.dart';

/// Expandable file list showing upload status.
///
/// Collapsed: shows "N files uploaded" or "Uploading..." summary.
/// Expanded: shows each file with status icon and dismiss button.
class UploadFileList extends StatefulWidget {
  const UploadFileList({
    super.key,
    required this.uploads,
    required this.onDismiss,
  });

  final ReadonlySignal<List<UploadEntry>> uploads;
  final void Function(String entryId) onDismiss;

  @override
  State<UploadFileList> createState() => _UploadFileListState();
}

class _UploadFileListState extends State<UploadFileList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.uploads.watch(context);
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final uploading = entries.where((e) => e.status == UploadStatus.uploading);
    final succeeded = entries.where((e) => e.status == UploadStatus.success);
    final failed = entries.where((e) => e.status is UploadError);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                if (uploading.isNotEmpty) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    _summary(uploading, succeeded, failed),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: failed.isNotEmpty
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            for (final entry in entries) _buildEntry(context, entry),
          ],
        ],
      ),
    );
  }

  String _summary(
    Iterable<UploadEntry> uploading,
    Iterable<UploadEntry> succeeded,
    Iterable<UploadEntry> failed,
  ) {
    final parts = <String>[];
    if (uploading.isNotEmpty) {
      parts.add('Uploading ${uploading.length}');
    }
    if (succeeded.isNotEmpty) {
      parts.add('${succeeded.length} uploaded');
    }
    if (failed.isNotEmpty) {
      parts.add('${failed.length} failed');
    }
    return parts.join(' \u00b7 ');
  }

  Widget _buildEntry(BuildContext context, UploadEntry entry) {
    final theme = Theme.of(context);
    final (icon, color, subtitle) = switch (entry.status) {
      UploadUploading() => (
          null,
          theme.colorScheme.primary,
          'Uploading...',
        ),
      UploadSuccess() => (
          Icons.check_circle_outline,
          theme.colorScheme.primary,
          'Uploaded',
        ),
      UploadError(:final message) => (
          Icons.error_outline,
          theme.colorScheme.error,
          message,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: color)
          else
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.filename,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.status is UploadError)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (entry.status is! UploadUploading)
            IconButton(
              icon: const Icon(Icons.close, size: 14),
              onPressed: () => widget.onDismiss(entry.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
