import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';

import '../../../../shared/failed_image.dart';
import 'code_block_builder.dart';
import 'data_uri_image.dart';
import 'file_image_loader.dart'
    if (dart.library.io) 'file_image_loader_io.dart';
import 'inline_code_builder.dart';
import 'markdown_renderer.dart';
import 'markdown_theme_extension.dart';

final _brTag = RegExp(r'<br\s*/?>');

String sanitizeMarkdown(String markdown) => markdown.replaceAll(_brTag, '\n');

String monospaceFont(TargetPlatform platform) {
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  return isApple ? 'SF Mono' : 'Roboto Mono';
}

class FlutterMarkdownPlusRenderer extends MarkdownRenderer {
  const FlutterMarkdownPlusRenderer({
    required super.data,
    super.onLinkTap,
    super.onImageTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final markdownTheme = Theme.of(context).extension<MarkdownThemeExtension>();
    final monoStyle = TextStyle(
      fontFamily: monospaceFont(Theme.of(context).platform),
      fontFamilyFallback: const ['monospace'],
    );

    return MarkdownBody(
      data: sanitizeMarkdown(data),
      selectable: true,
      styleSheet: markdownTheme?.toMarkdownStyleSheet(
        codeFontStyle: monoStyle,
      ),
      blockSyntaxes: [LatexBlockSyntax()],
      inlineSyntaxes: [LatexInlineSyntax()],
      onTapLink: onLinkTap == null
          ? null
          : (_, href, title) {
              if (href != null) onLinkTap!(href, title);
            },
      imageBuilder: _buildImage,
      builders: {
        'code': InlineCodeBuilder(),
        'pre': CodeBlockBuilder(
          preferredStyle: monoStyle.copyWith(fontSize: 14),
        ),
        'latex': LatexElementBuilder(),
      },
    );
  }
}

/// Equal-or-better coverage vs `kDefaultImageBuilder` in `flutter_markdown_plus`:
/// every scheme the default handles is handled here, with all failure paths
/// routed to a visible [FailedImage] (default uses an invisible `SizedBox`).
/// `file://` goes through [loadFileImage], which is conditional-imported —
/// `Image.file` on native, [FailedImage] on web (no filesystem).
Widget _buildImage(Uri uri, String? title, String? alt) {
  final rawUri = uri.toString();
  return switch (uri.scheme) {
    'data' => _buildDataImage(uri, alt, rawUri),
    'http' || 'https' => Image.network(
        rawUri,
        errorBuilder: (_, __, ___) => FailedImage(source: rawUri, label: alt),
      ),
    'resource' => Image.asset(
        uri.path,
        errorBuilder: (_, __, ___) => FailedImage(source: rawUri, label: alt),
      ),
    'file' => loadFileImage(uri, rawUri, alt),
    _ => FailedImage(source: rawUri, label: alt),
  };
}

Widget _buildDataImage(Uri uri, String? alt, String rawUri) {
  final data = uri.data;
  if (data == null) return FailedImage(source: rawUri, label: alt);

  final mime = data.mimeType;
  if (mime.startsWith('image/')) {
    final decoded = tryDecodeImageDataUri(rawUri);
    if (decoded == null) return FailedImage(source: rawUri, label: alt);
    return Image.memory(
      decoded.bytes,
      errorBuilder: (_, __, ___) => FailedImage(source: rawUri, label: alt),
    );
  }

  if (mime.startsWith('text/')) {
    try {
      return Text(data.contentAsString());
    } on FormatException {
      return FailedImage(source: rawUri, label: alt);
    }
  }

  return FailedImage(source: rawUri, label: alt);
}
