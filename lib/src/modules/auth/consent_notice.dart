import 'package:flutter/foundation.dart' show immutable;

/// Optional consent notice shown before authentication.
///
/// Flavors provide this when legal/compliance requires user acknowledgment
/// before connecting to a server.
@immutable
class ConsentNotice {
  const ConsentNotice({
    required this.title,
    required this.body,
    this.acknowledgmentLabel = 'OK',
  });

  final String title;
  final String body;
  final String acknowledgmentLabel;
}
