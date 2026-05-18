import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:soliplex_client/cancel_token.dart';
import 'package:soliplex_client/soliplex_client.dart' hide CancelToken;

/// HTTP client using Apple's NSURLSession via cupertino_http.
///
/// Provides native HTTP support on iOS and macOS with benefits including:
/// - Automatic proxy and VPN support
/// - HTTP/2 and HTTP/3 support
/// - System certificate trust evaluation
/// - Better battery efficiency
///
/// Example:
/// ```dart
/// final client = CupertinoHttpClient();
/// try {
///   final response = await client.request(
///     'GET',
///     Uri.parse('https://api.example.com/data'),
///   );
///   print(response.body);
/// } finally {
///   client.close();
/// }
/// ```
class CupertinoHttpClient implements SoliplexHttpClient {
  /// Creates a Cupertino HTTP client.
  ///
  /// Parameters:
  /// - [configuration]: Optional URLSessionConfiguration. If not provided,
  ///   an ephemeral configuration is created with [defaultTimeout] applied
  ///   to timeoutIntervalForRequest. When providing your own configuration,
  ///   you are responsible for its timeout settings.
  /// - [defaultTimeout]: Default timeout for requests.
  CupertinoHttpClient({
    URLSessionConfiguration? configuration,
    this.defaultTimeout = defaultHttpTimeout,
  }) : _client = CupertinoClient.fromSessionConfiguration(
          configuration ?? _createConfiguration(defaultTimeout),
        );

  /// Creates a Cupertino HTTP client with a custom client for testing.
  ///
  /// This constructor allows injecting a mock client for unit testing.
  @visibleForTesting
  CupertinoHttpClient.forTesting({
    required http.Client client,
    this.defaultTimeout = defaultHttpTimeout,
  }) : _client = client;

  /// Creates a URLSessionConfiguration with the given timeout.
  static URLSessionConfiguration _createConfiguration(Duration timeout) {
    return URLSessionConfiguration.ephemeralSessionConfiguration()
      ..timeoutIntervalForRequest = timeout;
  }

  final http.Client _client;

  /// Default timeout for requests when not specified per-request.
  final Duration defaultTimeout;

  bool _closed = false;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    _checkNotClosed();
    cancelToken?.throwIfCancelled();

    final effectiveTimeout = timeout ?? defaultTimeout;
    final request = _createRequest(method, uri, headers, body, cancelToken);

    try {
      final streamedResponse = await _client.send(request).timeout(
        effectiveTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Request timed out after ${effectiveTimeout.inSeconds}s',
            effectiveTimeout,
          );
        },
      );

      cancelToken?.throwIfCancelled();

      final bodyBytes = await streamedResponse.stream.toBytes().timeout(
        effectiveTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Response body timed out after ${effectiveTimeout.inSeconds}s',
            effectiveTimeout,
          );
        },
      );

      cancelToken?.throwIfCancelled();

      return HttpResponse(
        statusCode: streamedResponse.statusCode,
        bodyBytes: Uint8List.fromList(bodyBytes),
        headers: _normalizeHeaders(streamedResponse.headers),
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } on CancelledException {
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      throw NetworkException(
        message: e.message ?? 'Request timed out',
        isTimeout: true,
        originalError: e,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (e, stackTrace) {
      throw NetworkException(
        message: 'Client error: ${e.message}',
        originalError: e,
        stackTrace: stackTrace,
      );
    } on Exception catch (e, stackTrace) {
      // Generic fallback for platform-specific exceptions
      throw NetworkException(
        message: 'Network error: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    _checkNotClosed();
    cancelToken?.throwIfCancelled();

    final request = _createRequest(method, uri, headers, body, cancelToken);

    try {
      final streamedResponse = await _client.send(request);

      try {
        cancelToken?.throwIfCancelled();
      } on CancelledException {
        // Drain the stream to release the underlying TCP socket.
        unawaited(streamedResponse.stream.listen((_) {}).cancel());
        rethrow;
      }

      return StreamedHttpResponse(
        statusCode: streamedResponse.statusCode,
        headers: _normalizeHeaders(streamedResponse.headers),
        reasonPhrase: streamedResponse.reasonPhrase,
        body: streamedResponse.stream.handleError((
          Object error,
          StackTrace stackTrace,
        ) {
          throw NetworkException(
            message: 'Stream error: $error',
            originalError: error,
            stackTrace: stackTrace,
          );
        }),
      );
    } on CancelledException {
      rethrow;
    } on http.ClientException catch (e, stackTrace) {
      throw NetworkException(
        message: 'Client error: ${e.message}',
        originalError: e,
        stackTrace: stackTrace,
      );
    } on Exception catch (e, stackTrace) {
      throw NetworkException(
        message: 'Connection failed: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void close() {
    if (!_closed) {
      _closed = true;
      _client.close();
    }
  }

  /// Creates an HTTP request with the given parameters.
  ///
  /// Returns [http.StreamedRequest] for `Stream<List<int>>` bodies — used
  /// for streamed uploads with an exact `Content-Length`. Returns
  /// [http.Request] (buffered) for all other supported body types.
  http.BaseRequest _createRequest(
    String method,
    Uri uri,
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  ) {
    if (body is Stream<List<int>>) {
      return _createStreamedRequest(method, uri, headers, body, cancelToken);
    }

    final request = http.Request(method.toUpperCase(), uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (body != null) {
      if (body is String) {
        // Set content-type before body to prevent http package from overriding
        request.headers['content-type'] ??= 'text/plain; charset=utf-8';
        request.body = body;
      } else if (body is List<int>) {
        request.headers['content-type'] ??= 'application/octet-stream';
        request.bodyBytes = body;
      } else if (body is Map<String, dynamic>) {
        // Set content-type before body to prevent http package from overriding
        request.headers['content-type'] ??= 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      } else {
        throw ArgumentError(
          'Unsupported body type: ${body.runtimeType}. '
          'Use String, List<int>, Map<String, dynamic>, or Stream<List<int>>.',
        );
      }
    }

    return request;
  }

  /// Builds a [http.StreamedRequest] from a `Stream<List<int>>` body.
  ///
  /// Reads `content-length` from [headers] (case-insensitive) to set
  /// `request.contentLength` so the wire uses an exact `Content-Length`
  /// header rather than `Transfer-Encoding: chunked`. Callers MUST supply
  /// content-length for streamed bodies.
  ///
  /// Wires [cancelToken] to inject an error into the request sink —
  /// `cupertino_http`'s `NSURLSessionTask` aborts cleanly on sink error.
  http.StreamedRequest _createStreamedRequest(
    String method,
    Uri uri,
    Map<String, String>? headers,
    Stream<List<int>> body,
    CancelToken? cancelToken,
  ) {
    final request = http.StreamedRequest(method.toUpperCase(), uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    final contentLength = _findHeader(headers, 'content-length');
    if (contentLength != null) {
      request.contentLength = int.parse(contentLength);
    }
    request.headers['content-type'] ??= 'application/octet-stream';

    _pipeStreamToSink(body, request.sink, cancelToken);
    return request;
  }

  /// Pipes [source] chunks into [sink], honoring [cancelToken] by injecting
  /// a [CancelledException] into the sink. The underlying client treats a
  /// sink error as an abrupt connection abort.
  void _pipeStreamToSink(
    Stream<List<int>> source,
    EventSink<List<int>> sink,
    CancelToken? cancelToken,
  ) {
    StreamSubscription<void>? cancelSub;
    var closed = false;

    void closeSink() {
      if (closed) return;
      closed = true;
      sink.close();
    }

    final subscription = source.listen(
      sink.add,
      onError: (Object error, StackTrace stack) {
        if (closed) return;
        sink.addError(error, stack);
        closeSink();
      },
      onDone: () {
        cancelSub?.cancel();
        closeSink();
      },
    );

    if (cancelToken != null) {
      cancelSub = cancelToken.whenCancelled.asStream().listen((_) {
        if (closed) return;
        sink.addError(CancelledException(reason: cancelToken.reason));
        closeSink();
        subscription.cancel();
      });
    }
  }

  /// Case-insensitive header lookup.
  String? _findHeader(Map<String, String>? headers, String name) {
    if (headers == null) return null;
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  /// Normalizes headers by converting keys to lowercase.
  Map<String, String> _normalizeHeaders(Map<String, String> headers) {
    return headers.map((key, value) => MapEntry(key.toLowerCase(), value));
  }

  /// Checks that the client has not been closed.
  void _checkNotClosed() {
    if (_closed) {
      throw StateError(
        'Cannot use CupertinoHttpClient after close() was called',
      );
    }
  }
}
