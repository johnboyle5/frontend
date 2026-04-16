import 'dart:async';
import 'dart:collection';

import 'package:soliplex_client/src/errors/exceptions.dart';
import 'package:soliplex_client/src/http/concurrency_observer.dart';
import 'package:soliplex_client/src/http/http_redactor.dart';
import 'package:soliplex_client/src/http/http_response.dart';
import 'package:soliplex_client/src/http/soliplex_http_client.dart';
import 'package:soliplex_client/src/utils/cancel_token.dart';

/// HTTP client decorator that caps in-flight requests at [maxConcurrent].
///
/// Excess requests queue in FIFO order and dispatch as earlier requests
/// release their slots. Queued stream requests drop out of the queue
/// immediately when their [CancelToken] fires — no slot is acquired.
///
/// Emits [HttpConcurrencyWaitEvent] to observers on every slot
/// acquisition, including acquisitions with `waitDuration == 0`.
///
/// ## Streams
///
/// [requestStream] holds its slot for the response body's entire
/// lifetime — released when the body stream completes, errors, or is
/// cancelled. This accurately models what the upstream sees (an open
/// connection). Default [maxConcurrent] is 10, matching Nginx's
/// `limit_conn conn 10`.
///
/// ## Decorator order
///
/// Place below `AuthenticatedHttpClient` so queued requests don't hold
/// stale tokens, and above `ObservableHttpClient` so each wire attempt
/// is observed individually.
///
/// ```text
/// Refreshing -> Authenticated -> Concurrency -> Observable -> Platform
/// ```
class ConcurrencyLimitingHttpClient implements SoliplexHttpClient {
  /// Creates a concurrency-limiting HTTP client.
  ///
  /// - [inner]: The wrapped HTTP client.
  /// - [maxConcurrent]: Maximum in-flight requests (default 10).
  /// - [observers]: Observers notified of queue-wait events.
  /// - [generateRequestId]: Optional ID generator; defaults to a
  ///   timestamp+counter scheme.
  /// - [clock]: Test injection point for deterministic `waitDuration`.
  ConcurrencyLimitingHttpClient({
    required SoliplexHttpClient inner,
    this.maxConcurrent = 10,
    List<ConcurrencyObserver> observers = const [],
    String Function()? generateRequestId,
    DateTime Function()? clock,
  })  : assert(maxConcurrent >= 1, 'maxConcurrent must be at least 1'),
        _inner = inner,
        _observers = List.unmodifiable(observers),
        _generateRequestId = generateRequestId ?? _defaultRequestIdGenerator,
        _clock = clock ?? DateTime.now,
        _semaphore = _Semaphore(maxConcurrent);

  final SoliplexHttpClient _inner;
  final List<ConcurrencyObserver> _observers;
  final String Function() _generateRequestId;
  final DateTime Function() _clock;
  final _Semaphore _semaphore;

  /// Maximum in-flight requests.
  final int maxConcurrent;

  static int _requestCounter = 0;

  static String _defaultRequestIdGenerator() =>
      'cc-${DateTime.now().millisecondsSinceEpoch}-${_requestCounter++}';

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestId = _generateRequestId();
    final enqueuedAt = _clock();
    final depthAtEnqueue = _semaphore.inUseCount + _semaphore.waitingCount;

    // request() has no CancelToken in the SoliplexHttpClient interface,
    // so we can't cancel queued non-stream requests.
    final wasQueued = await _semaphore.acquire();

    final acquiredAt = _clock();
    _emitConcurrencyWait(
      requestId: requestId,
      uri: uri,
      timestamp: acquiredAt,
      waitDuration:
          wasQueued ? acquiredAt.difference(enqueuedAt) : Duration.zero,
      queueDepthAtEnqueue: depthAtEnqueue,
    );

    try {
      return await _inner.request(
        method,
        uri,
        headers: headers,
        body: body,
        timeout: timeout,
      );
    } finally {
      _semaphore.release();
    }
  }

  /// Acquires a semaphore slot, delegates to the inner client, and
  /// wraps the response body so the slot is released on stream
  /// complete/error/cancel.
  ///
  /// **Precondition:** callers MUST listen to the returned
  /// [StreamedHttpResponse.body]. An unlistened body stream will hold
  /// the semaphore slot indefinitely, starving other requests.
  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();

    final requestId = _generateRequestId();
    final enqueuedAt = _clock();
    final depthAtEnqueue = _semaphore.inUseCount + _semaphore.waitingCount;

    final wasQueued = await _semaphore.acquire(cancelToken: cancelToken);

    StreamedHttpResponse response;
    try {
      cancelToken?.throwIfCancelled();

      final acquiredAt = _clock();
      _emitConcurrencyWait(
        requestId: requestId,
        uri: uri,
        timestamp: acquiredAt,
        waitDuration:
            wasQueued ? acquiredAt.difference(enqueuedAt) : Duration.zero,
        queueDepthAtEnqueue: depthAtEnqueue,
      );

      response = await _inner.requestStream(
        method,
        uri,
        headers: headers,
        body: body,
        cancelToken: cancelToken,
      );
    } on Object {
      _semaphore.release();
      rethrow;
    }

    return StreamedHttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      body: _wrapBodyWithRelease(response.body),
    );
  }

  /// Wraps a body stream so the semaphore slot is released when the
  /// stream completes, errors, or is cancelled.
  Stream<List<int>> _wrapBodyWithRelease(Stream<List<int>> source) {
    var released = false;
    void releaseOnce() {
      if (!released) {
        released = true;
        _semaphore.release();
      }
    }

    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        subscription = source.listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            releaseOnce();
            controller.addError(error, stackTrace);
          },
          onDone: () {
            releaseOnce();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        releaseOnce();
        return subscription?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  void close() => _inner.close();

  void _emitConcurrencyWait({
    required String requestId,
    required Uri uri,
    required DateTime timestamp,
    required Duration waitDuration,
    required int queueDepthAtEnqueue,
  }) {
    if (_observers.isEmpty) return;

    final redactedUri = HttpRedactor.redactUri(uri);
    final event = HttpConcurrencyWaitEvent(
      requestId: requestId,
      timestamp: timestamp,
      uri: redactedUri,
      waitDuration: waitDuration,
      queueDepthAtEnqueue: queueDepthAtEnqueue,
      slotsInUseAfterAcquire: _semaphore.inUseCount,
    );

    for (final observer in _observers) {
      try {
        observer.onConcurrencyWait(event);
      } on Object {
        // Observer failures must not disrupt the request flow.
      }
    }
  }
}

/// Cancel-aware FIFO semaphore.
///
/// [acquire] returns immediately if a permit is available; otherwise
/// the caller is queued. If a [CancelToken] is passed and fires while
/// the caller is queued, the completer is removed from the queue and
/// completed with a [CancelledException] — no permit is acquired.
class _Semaphore {
  _Semaphore(this.maxCount) : _available = maxCount;

  final int maxCount;
  int _available;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  int get inUseCount => maxCount - _available;

  int get waitingCount => _waiters.length;

  /// Returns `true` if the caller was queued, `false` if a permit was
  /// available immediately.
  Future<bool> acquire({CancelToken? cancelToken}) {
    if (_available > 0) {
      _available--;
      return Future<bool>.value(false);
    }
    cancelToken?.throwIfCancelled();

    final completer = Completer<void>();
    _waiters.add(completer);

    if (cancelToken != null) {
      cancelToken.whenCancelled.then((_) {
        if (!completer.isCompleted) {
          _waiters.remove(completer);
          completer.completeError(
            CancelledException(reason: cancelToken.reason),
          );
        }
      });
    }

    return completer.future.then((_) => true);
  }

  void release() {
    // Skip waiters that were already completed by CancelToken — handing
    // them the permit would waste it (the caller already threw).
    while (_waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (!next.isCompleted) {
        next.complete();
        return;
      }
    }
    _available++;
  }
}
