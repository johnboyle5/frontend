import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../copy_button.dart';

class ImageDataUri {
  const ImageDataUri({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

ImageDataUri? tryDecodeImageDataUri(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null || uri.scheme != 'data') return null;

  final data = uri.data;
  if (data == null) return null;

  if (!data.mimeType.startsWith('image/')) return null;

  // Validate base64 length explicitly against the raw source string. Dart's
  // UriData normalizes its contentText (it silently appends `=` padding to
  // truncated input on the VM, while web throws). Consult the original `src`
  // so behavior is identical on both platforms.
  if (data.isBase64) {
    final commaIdx = src.indexOf(',');
    if (commaIdx < 0) return null;
    final rawPayload = src.substring(commaIdx + 1);
    if (rawPayload.isEmpty || rawPayload.length % 4 != 0) return null;
  }

  try {
    return ImageDataUri(
      bytes: Uint8List.fromList(data.contentAsBytes()),
      mimeType: data.mimeType,
    );
  } on FormatException {
    return null;
  }
}

class BrokenImagePlaceholder extends StatelessWidget {
  const BrokenImagePlaceholder({this.alt, super.key});

  final String? alt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label =
        (alt != null && alt!.isNotEmpty) ? alt! : 'Image failed to load';
    return Semantics(
      label: label,
      image: true,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.broken_image,
          color: scheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    );
  }
}

/// Renders a failed data-URI image with a toolbar (alt label, preview/source
/// toggle, Copy button). Preview shows a [BrokenImagePlaceholder]; source
/// shows the raw URI as selectable monospace text so the user can inspect
/// what the agent actually emitted.
class BrokenDataUriBlock extends StatefulWidget {
  const BrokenDataUriBlock({required this.rawUri, this.alt, super.key});

  final String rawUri;
  final String? alt;

  @override
  State<BrokenDataUriBlock> createState() => _BrokenDataUriBlockState();
}

class _BrokenDataUriBlockState extends State<BrokenDataUriBlock> {
  bool _showSource = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(theme),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _showSource
              ? _sourceView(theme)
              : Center(child: BrokenImagePlaceholder(alt: widget.alt)),
        ),
      ],
    );
  }

  Widget _sourceView(ThemeData theme) {
    return SelectableText(
      widget.rawUri,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['monospace'],
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _toolbar(ThemeData theme) {
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final alt = widget.alt;
    final label = (alt != null && alt.isNotEmpty) ? alt : 'broken image';
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Text(label, style: labelStyle),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Tooltip(
            message: _showSource ? 'Show preview' : 'Show source',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() => _showSource = !_showSource),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _showSource ? Icons.image : Icons.code,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4, top: 4),
          child: CopyButton(
            text: widget.rawUri,
            tooltip: 'Copy data URI',
            iconSize: 16,
          ),
        ),
      ],
    );
  }
}
