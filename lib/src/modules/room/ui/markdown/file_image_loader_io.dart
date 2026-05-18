import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/failed_image.dart';

/// Native implementation of [loadFileImage] for platforms with `dart:io`.
/// Constructs a [File] from the URI and renders via [Image.file]; any
/// construction or decode failure routes to [FailedImage].
Widget loadFileImage(Uri uri, String rawUri, String? alt) {
  try {
    return Image.file(
      File.fromUri(uri),
      errorBuilder: (_, __, ___) => FailedImage(source: rawUri, label: alt),
    );
  } on Object {
    return FailedImage(source: rawUri, label: alt);
  }
}
