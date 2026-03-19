/// Callback parameters extracted from the auth callback URL.
sealed class CallbackParams {
  const CallbackParams();

  /// The error message if authentication failed.
  String? get error;

  /// Whether an error occurred.
  bool get hasError => error != null;
}

/// Callback parameters for web BFF OAuth flow.
///
/// The backend exchanges the authorization code for tokens and redirects
/// back with tokens in the URL query parameters.
class WebCallbackParams extends CallbackParams {
  const WebCallbackParams({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.error,
    this.errorDescription,
  });

  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;

  @override
  final String? error;
  final String? errorDescription;

  @override
  String toString() => 'WebCallbackParams('
      'hasAccessToken: ${accessToken != null}, '
      'hasRefreshToken: ${refreshToken != null}, '
      'expiresIn: $expiresIn, '
      'error: $error)';
}

/// No callback parameters detected.
class NoCallbackParams extends CallbackParams {
  const NoCallbackParams();

  @override
  String? get error => null;

  @override
  String toString() => 'NoCallbackParams()';
}
