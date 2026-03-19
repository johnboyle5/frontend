import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'callback_service.dart';

/// Captures callback params from current URL.
CallbackParams captureCallbackParamsNow() => _extractParamsFromUrl();

/// Clears OAuth callback parameters from the browser URL.
void clearCallbackUrl() {
  final origin = web.window.location.origin;
  final pathname = web.window.location.pathname;
  var hash = web.window.location.hash;

  if (hash.isNotEmpty) {
    final queryIndex = hash.indexOf('?');
    if (queryIndex != -1) {
      hash = hash.substring(0, queryIndex);
    }
  }

  final cleanUrl = '$origin$pathname$hash';
  web.window.history.replaceState(JSObject(), '', cleanUrl);
}

CallbackParams _extractParamsFromUrl() {
  final params = _getQueryParams();
  if (params.isEmpty) return const NoCallbackParams();

  final error = params['error'];
  final errorDescription = params['error_description'];
  final accessToken = params['token'] ?? params['access_token'];

  if (accessToken != null || error != null) {
    return WebCallbackParams(
      accessToken: accessToken,
      refreshToken: params['refresh_token'],
      expiresIn: _parseIntOrNull(params['expires_in']),
      error: error,
      errorDescription: errorDescription,
    );
  }

  return const NoCallbackParams();
}

Map<String, String> _getQueryParams() {
  final search = web.window.location.search;
  if (search.isNotEmpty) {
    return Uri.splitQueryString(search.substring(1));
  }

  final hash = web.window.location.hash;
  if (hash.isNotEmpty) {
    final queryIndex = hash.indexOf('?');
    if (queryIndex != -1) {
      return Uri.splitQueryString(hash.substring(queryIndex + 1));
    }
  }

  return {};
}

int? _parseIntOrNull(String? value) {
  if (value == null) return null;
  return int.tryParse(value);
}
