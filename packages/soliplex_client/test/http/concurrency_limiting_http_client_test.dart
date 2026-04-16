import 'dart:async';
import 'dart:typed_data';

import 'package:soliplex_client/soliplex_client.dart' hide CancelToken;
import 'package:soliplex_client/src/utils/cancel_token.dart';
import 'package:test/test.dart';

/// Fake inner client that gates every response on a Completer so tests
/// can control request/response timing precisely.
class _GatedInner implements SoliplexHttpClient {
  final List<_PendingRequest> pending = [];
  int requestCallCount = 0;
  int streamCallCount = 0;

  _PendingRequest queueNextRequest() {
    final p = _PendingRequest();
    pending.add(p);
    return p;
  }

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    requestCallCount++;
    if (pending.isEmpty) {
      return HttpResponse(statusCode: 200, bodyBytes: Uint8List(0));
    }
    return pending.removeAt(0).future;
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    streamCallCount++;
    return const StreamedHttpResponse(statusCode: 200, body: Stream.empty());
  }

  @override
  void close() {}
}

class _PendingRequest {
  final _completer = Completer<HttpResponse>();
  Future<HttpResponse> get future => _completer.future;

  void complete() => _completer.complete(
        HttpResponse(statusCode: 200, bodyBytes: Uint8List(0)),
      );
  void fail(Object error) => _completer.completeError(error);
}

class _RecordingObserver implements ConcurrencyObserver {
  final events = <HttpConcurrencyWaitEvent>[];

  @override
  void onConcurrencyWait(HttpConcurrencyWaitEvent event) => events.add(event);
}

/// Observer that throws on every call. Verifies the decorator's
/// try-catch around observer dispatch prevents a broken observer from
/// crashing the request flow.
class _ThrowingObserver implements ConcurrencyObserver {
  int callCount = 0;

  @override
  void onConcurrencyWait(HttpConcurrencyWaitEvent event) {
    callCount++;
    throw Exception('observer is broken');
  }
}

/// Inner that returns a stream with a controllable body, so tests can
/// hold the body open and verify the slot is held for its lifetime.
class _StreamBodyInner implements SoliplexHttpClient {
  _StreamBodyInner(this._body);
  final Stream<List<int>> _body;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async =>
      HttpResponse(statusCode: 200, bodyBytes: Uint8List(0));

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async =>
      StreamedHttpResponse(statusCode: 200, body: _body);

  @override
  void close() {}
}

class _CloseCounter implements SoliplexHttpClient {
  _CloseCounter(this._onClose);
  final void Function() _onClose;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async =>
      HttpResponse(statusCode: 200, bodyBytes: Uint8List(0));

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async =>
      const StreamedHttpResponse(statusCode: 200, body: Stream.empty());

  @override
  void close() => _onClose();
}

/// Inner that throws synchronously on request() when [throwOnNext] is true.
/// Verifies the decorator's try/finally releases the slot even when the
/// inner throws before returning a Future (as opposed to inside an awaited
/// future).
class _SyncThrowingInner implements SoliplexHttpClient {
  bool throwOnNext = true;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) {
    if (throwOnNext) {
      throw const NetworkException(message: 'sync boom');
    }
    return Future.value(
      HttpResponse(statusCode: 200, bodyBytes: Uint8List(0)),
    );
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async =>
      const StreamedHttpResponse(statusCode: 200, body: Stream.empty());

  @override
  void close() {}
}

/// Inner that throws from `requestStream` after the caller has acquired
/// a slot. Separate sync/async failure modes — the decorator's
/// `on Object { release; rethrow; }` block must handle both.
class _StreamThrowingInner implements SoliplexHttpClient {
  _StreamThrowingInner({this.synchronous = false});
  final bool synchronous;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async =>
      HttpResponse(statusCode: 200, bodyBytes: Uint8List(0));

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) {
    if (synchronous) {
      throw const NetworkException(message: 'stream sync boom');
    }
    return Future<StreamedHttpResponse>.error(
      const NetworkException(message: 'stream async boom'),
    );
  }

  @override
  void close() {}
}

/// Inner whose `requestStream` runs a scripted sequence of responses;
/// anything past the script delegates to [fallback] for `request`.
/// `request` always delegates to [fallback].
class _SequentialInner implements SoliplexHttpClient {
  _SequentialInner(this._streamScript, {required this.fallback});
  final List<Future<StreamedHttpResponse> Function()> _streamScript;
  final SoliplexHttpClient fallback;
  int _streamIndex = 0;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) =>
      fallback.request(
        method,
        uri,
        headers: headers,
        body: body,
        timeout: timeout,
      );

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) {
    if (_streamIndex < _streamScript.length) {
      return _streamScript[_streamIndex++]();
    }
    return fallback.requestStream(
      method,
      uri,
      headers: headers,
      body: body,
      cancelToken: cancelToken,
    );
  }

  @override
  void close() => fallback.close();
}

/// Mutable clock for deterministic waitDuration assertions.
class _MockClock {
  DateTime now = DateTime(2026);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  group('ConcurrencyLimitingHttpClient.request', () {
    test('single request passes through immediately', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 2,
      );

      final response = await client.request(
        'GET',
        Uri.parse('https://x/y'),
      );

      expect(response.statusCode, 200);
      expect(inner.requestCallCount, 1);
    });

    test('caps in-flight requests at maxConcurrent', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 2,
      );

      final pending = [
        inner.queueNextRequest(),
        inner.queueNextRequest(),
        inner.queueNextRequest(),
      ];

      final futures = [
        client.request('GET', Uri.parse('https://x/1')),
        client.request('GET', Uri.parse('https://x/2')),
        client.request('GET', Uri.parse('https://x/3')),
      ];

      await Future<void>.delayed(Duration.zero);

      expect(
        inner.requestCallCount,
        2,
        reason: 'Third request must queue until a slot frees',
      );

      pending[0].complete();
      await Future<void>.delayed(Duration.zero);
      expect(inner.requestCallCount, 3);

      pending[1].complete();
      pending[2].complete();
      await Future.wait<void>(futures);
    });

    test('queue is FIFO', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final acquiredOrder = <int>[];
      final pending = [
        inner.queueNextRequest(),
        inner.queueNextRequest(),
        inner.queueNextRequest(),
      ];

      final futures = [
        client.request('GET', Uri.parse('https://x/a')).then((_) {
          acquiredOrder.add(1);
        }),
        client.request('GET', Uri.parse('https://x/b')).then((_) {
          acquiredOrder.add(2);
        }),
        client.request('GET', Uri.parse('https://x/c')).then((_) {
          acquiredOrder.add(3);
        }),
      ];

      await Future<void>.delayed(Duration.zero);

      pending[0].complete();
      await Future<void>.delayed(Duration.zero);
      pending[1].complete();
      await Future<void>.delayed(Duration.zero);
      pending[2].complete();

      await Future.wait<void>(futures);

      expect(acquiredOrder, equals([1, 2, 3]));
    });

    test('releases slot after inner throws', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final first = inner.queueNextRequest();
      final second = inner.queueNextRequest();

      final firstFuture = client.request('GET', Uri.parse('https://x/1'));
      final secondFuture = client.request('GET', Uri.parse('https://x/2'));

      await Future<void>.delayed(Duration.zero);
      expect(inner.requestCallCount, 1);

      first.fail(const NetworkException(message: 'blip'));
      await expectLater(firstFuture, throwsA(isA<NetworkException>()));

      second.complete();
      await secondFuture;
      expect(inner.requestCallCount, 2);
    });

    test('releases slot when inner throws synchronously', () async {
      final inner = _SyncThrowingInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      await expectLater(
        () => client.request('GET', Uri.parse('https://x/1')),
        throwsA(isA<NetworkException>()),
      );

      inner.throwOnNext = false;
      final response = await client.request('GET', Uri.parse('https://x/2'));
      expect(response.statusCode, 200);
    });
  });

  group('ConcurrencyLimitingHttpClient observers', () {
    test('emits onConcurrencyWait with waitDuration=0 when not queued',
        () async {
      final inner = _GatedInner();
      final observer = _RecordingObserver();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 2,
        observers: [observer],
      );

      await client.request('GET', Uri.parse('https://x/y'));

      expect(observer.events.length, 1);
      final event = observer.events[0];
      expect(event.waitDuration, Duration.zero);
      expect(event.queueDepthAtEnqueue, 0);
      expect(event.slotsInUseAfterAcquire, 1);
      expect(event.uri.toString(), equals('https://x/y'));
    });

    test(
        'emits onConcurrencyWait with deterministic non-zero waitDuration '
        'when queued', () async {
      final inner = _GatedInner();
      final observer = _RecordingObserver();
      final clock = _MockClock();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
        observers: [observer],
        clock: clock.call,
      );

      final first = inner.queueNextRequest();
      final second = inner.queueNextRequest();

      final firstFuture = client.request('GET', Uri.parse('https://x/1'));
      final secondFuture = client.request('GET', Uri.parse('https://x/2'));

      await Future<void>.delayed(Duration.zero);

      clock.advance(const Duration(milliseconds: 50));

      first.complete();
      await firstFuture;
      second.complete();
      await secondFuture;

      expect(observer.events.length, 2);
      expect(observer.events[0].waitDuration, Duration.zero);
      expect(
        observer.events[1].waitDuration,
        equals(const Duration(milliseconds: 50)),
      );
      expect(observer.events[1].queueDepthAtEnqueue, 1);
    });

    test('swallows observer exceptions without breaking the request', () async {
      final inner = _GatedInner();
      final throwingObserver = _ThrowingObserver();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 2,
        observers: [throwingObserver],
      );

      final response = await client.request(
        'GET',
        Uri.parse('https://x/y'),
      );

      expect(response.statusCode, 200);
      expect(throwingObserver.callCount, 1);
    });

    test('continues notifying remaining observers after one throws', () async {
      final inner = _GatedInner();
      final throwingObserver = _ThrowingObserver();
      final recordingObserver = _RecordingObserver();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 2,
        observers: [throwingObserver, recordingObserver],
      );

      await client.request('GET', Uri.parse('https://x/y'));

      expect(throwingObserver.callCount, 1);
      expect(
        recordingObserver.events.length,
        1,
        reason: 'Second observer must still receive the event',
      );
    });
  });

  group('ConcurrencyLimitingHttpClient.requestStream', () {
    test('holds slot until body stream closes, then releases', () async {
      final bodyController = StreamController<List<int>>();
      final inner = _StreamBodyInner(bodyController.stream);
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final response = await client.requestStream(
        'GET',
        Uri.parse('https://x/stream'),
      );
      expect(response.statusCode, 200);

      var secondStarted = false;
      final secondFuture =
          client.request('GET', Uri.parse('https://x/rest')).then((r) {
        secondStarted = true;
        return r;
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        secondStarted,
        isFalse,
        reason: 'Slot held by stream; second request must wait',
      );

      final drainFuture = response.body.drain<void>();
      await bodyController.close();
      await drainFuture;

      await secondFuture;
      expect(secondStarted, isTrue);
    });

    test('releases slot when body stream errors', () async {
      final bodyController = StreamController<List<int>>();
      final inner = _StreamBodyInner(bodyController.stream);
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final response = await client.requestStream(
        'GET',
        Uri.parse('https://x/stream'),
      );

      final drainFuture = response.body.drain<void>().catchError((_) {});
      bodyController.addError(Exception('stream broke'));
      await bodyController.close();
      await drainFuture;

      final second = await client.request('GET', Uri.parse('https://x/rest'));
      expect(second.statusCode, 200);
    });

    test(
        'throws CancelledException and does not acquire when cancelled '
        'before acquire', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final cancelToken = CancelToken()..cancel('pre-emptive');

      await expectLater(
        () => client.requestStream(
          'GET',
          Uri.parse('https://x/stream'),
          cancelToken: cancelToken,
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(inner.streamCallCount, 0);
    });

    test('queued stream cancel drops out of queue without acquiring', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final firstPending = inner.queueNextRequest();
      final firstFuture = client.request('GET', Uri.parse('https://x/first'));

      await Future<void>.delayed(Duration.zero);
      expect(inner.requestCallCount, 1);

      final cancelToken = CancelToken();
      final streamFuture = client.requestStream(
        'GET',
        Uri.parse('https://x/stream'),
        cancelToken: cancelToken,
      );
      await Future<void>.delayed(Duration.zero);

      cancelToken.cancel('navigated away');

      await expectLater(streamFuture, throwsA(isA<CancelledException>()));
      expect(inner.streamCallCount, 0);

      firstPending.complete();
      await firstFuture;
      expect(inner.streamCallCount, 0);
    });
  });

  group('ConcurrencyLimitingHttpClient mixed request/stream queue', () {
    test('FIFO applies across request and requestStream uniformly', () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final dispatchOrder = <String>[];

      final firstPending = inner.queueNextRequest();
      final thirdPending = inner.queueNextRequest();

      final firstFuture = client
          .request('GET', Uri.parse('https://x/1'))
          .then((_) => dispatchOrder.add('request-1'));
      await Future<void>.delayed(Duration.zero);
      expect(inner.requestCallCount, 1);

      final streamFuture =
          client.requestStream('GET', Uri.parse('https://x/2')).then((r) {
        dispatchOrder.add('stream-2');
        return r;
      });
      final thirdFuture = client
          .request('GET', Uri.parse('https://x/3'))
          .then((_) => dispatchOrder.add('request-3'));
      await Future<void>.delayed(Duration.zero);

      expect(inner.requestCallCount, 1);
      expect(inner.streamCallCount, 0);

      firstPending.complete();
      await firstFuture;
      await Future<void>.delayed(Duration.zero);
      expect(inner.streamCallCount, 1);

      // The stream's body is Stream.empty() — draining it releases the slot.
      final streamResponse = await streamFuture;
      await streamResponse.body.drain<void>();
      await Future<void>.delayed(Duration.zero);
      expect(inner.requestCallCount, 2);

      thirdPending.complete();
      await thirdFuture;

      expect(
        dispatchOrder,
        equals(['request-1', 'stream-2', 'request-3']),
        reason: 'Mixed queue must dispatch in arrival order regardless of type',
      );
    });
  });

  group('ConcurrencyLimitingHttpClient slot lifecycle regressions', () {
    test('releases slot when inner.requestStream throws asynchronously',
        () async {
      final inner = _StreamThrowingInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      await expectLater(
        () => client.requestStream('GET', Uri.parse('https://x/stream')),
        throwsA(isA<NetworkException>()),
      );

      // If the slot leaked, the next request would hang forever.
      final response = await client.request('GET', Uri.parse('https://x/ok'));
      expect(response.statusCode, 200);
    });

    test('releases slot when inner.requestStream throws synchronously',
        () async {
      final inner = _StreamThrowingInner(synchronous: true);
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      await expectLater(
        () => client.requestStream('GET', Uri.parse('https://x/stream')),
        throwsA(isA<NetworkException>()),
      );

      final response = await client.request('GET', Uri.parse('https://x/ok'));
      expect(response.statusCode, 200);
    });

    test('cancelled waiter in queue is skipped; next live waiter dispatches',
        () async {
      final inner = _GatedInner();
      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      // Hold the single slot with a non-completing request.
      final heldPending = inner.queueNextRequest();
      final heldFuture = client.request('GET', Uri.parse('https://x/held'));
      await Future<void>.delayed(Duration.zero);
      expect(inner.requestCallCount, 1);

      // Enqueue three stream requests behind the held slot.
      final cancelA = CancelToken();
      final cancelB = CancelToken();
      final cancelC = CancelToken();
      final streamA = client.requestStream(
        'GET',
        Uri.parse('https://x/a'),
        cancelToken: cancelA,
      );
      final streamB = client.requestStream(
        'GET',
        Uri.parse('https://x/b'),
        cancelToken: cancelB,
      );
      final streamC = client.requestStream(
        'GET',
        Uri.parse('https://x/c'),
        cancelToken: cancelC,
      );
      await Future<void>.delayed(Duration.zero);

      // Cancel the MIDDLE waiter. Its completer is marked cancelled but
      // stays nominally in the queue ordering — release() must skip it.
      cancelB.cancel('skip me');
      await expectLater(streamB, throwsA(isA<CancelledException>()));

      // Release the held slot. Our regression-sensitive path:
      // release() iterates waiters, sees cancelled B, skips it, hands
      // the permit to A (not C).
      heldPending.complete();
      await heldFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        inner.streamCallCount,
        1,
        reason: 'Exactly one of the live waiters should have dispatched',
      );

      // Clean up remaining waiters.
      cancelA.cancel('cleanup');
      cancelC.cancel('cleanup');
      // A already dispatched (inner.streamCallCount == 1), so we expect
      // its stream to resolve normally; C was still queued and should
      // throw.
      await expectLater(streamC, throwsA(isA<CancelledException>()));
      await streamA;
    });

    test('body that emits error then done releases the slot exactly once',
        () async {
      // An inner that serves one error-terminated body stream, then
      // delegates subsequent requests to a gated fake. If the body
      // wrapper over-released (two decrements, so effectively +1 slot),
      // the cap would rise from 1 to 2 and two gated requests would
      // dispatch concurrently. The regression signal is cap violation.
      final errorBody = StreamController<List<int>>();
      final gated = _GatedInner();
      final inner = _SequentialInner(
        [
          () async => StreamedHttpResponse(
                statusCode: 200,
                body: errorBody.stream,
              ),
        ],
        fallback: gated,
      );

      final client = ConcurrencyLimitingHttpClient(
        inner: inner,
        maxConcurrent: 1,
      );

      final response = await client.requestStream(
        'GET',
        Uri.parse('https://x/stream'),
      );
      // Start draining before closing the source so the listener is
      // attached; otherwise close() blocks on no subscriber.
      final drained = response.body.drain<void>().catchError((_) {});
      errorBody.addError(Exception('boom'));
      await errorBody.close();
      await drained;

      // Slot should be back to 1 available. Fire two gated requests.
      final q1 = gated.queueNextRequest();
      gated.queueNextRequest(); // second one must queue
      final f1 = client.request('GET', Uri.parse('https://x/1'));
      final f2 = client.request('GET', Uri.parse('https://x/2'));
      await Future<void>.delayed(Duration.zero);

      expect(
        gated.requestCallCount,
        1,
        reason: 'Cap must still be 1 after body error+done — no double '
            'release into _available',
      );

      q1.complete();
      await f1;
      // The second queued request then dispatches; let it finish.
      gated.pending.first.complete();
      await f2;
    });

    test('cancelling the body subscription mid-flight releases the slot',
        () async {
      final body = StreamController<List<int>>();
      final client = ConcurrencyLimitingHttpClient(
        inner: _StreamBodyInner(body.stream),
        maxConcurrent: 1,
      );

      final response = await client.requestStream(
        'GET',
        Uri.parse('https://x/stream'),
      );
      final received = <List<int>>[];
      final sub = response.body.listen(received.add);

      body.add([1, 2, 3]);
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));

      // Cancel the subscription mid-flight. The body wrapper's
      // onCancel must release the slot.
      await sub.cancel();
      await body.close();

      // If the slot leaked, this next request would hang forever.
      final follow = await client.request('GET', Uri.parse('https://x/ok'));
      expect(follow.statusCode, 200);
    });
  });

  test('close delegates to inner', () {
    var closed = 0;
    final inner = _CloseCounter(() => closed++);
    ConcurrencyLimitingHttpClient(inner: inner, maxConcurrent: 1).close();
    expect(closed, 1);
  });
}
