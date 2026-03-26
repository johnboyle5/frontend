import 'package:flutter/widgets.dart';

typedef MarkdownLinkHandler = void Function(String href, String? title);
typedef MarkdownImageHandler = void Function(String src, String? alt);

abstract class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    required this.data,
    this.onLinkTap,
    this.onImageTap,
    super.key,
  });

  final String data;
  final MarkdownLinkHandler? onLinkTap;
  final MarkdownImageHandler? onImageTap;
}
