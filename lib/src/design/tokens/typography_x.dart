import 'package:flutter/material.dart';

import '../../shared/platform_resolver.dart';

TextStyle appMonospaceTextStyle(BuildContext context) {
  final base = Theme.of(context).textTheme.bodyMedium;

  if (isCupertino(context)) {
    return base!.copyWith(
      fontFamily: 'SF Mono',
      fontFamilyFallback: const ['Menlo', 'monospace'],
    );
  }

  return base!.copyWith(
    fontFamily: 'Roboto Mono',
    fontFamilyFallback: const ['monospace'],
  );
}

extension TypographyX on BuildContext {
  TextStyle get monospace => appMonospaceTextStyle(this);
}
