import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart' hide CancelToken;
import 'package:test/test.dart';

class MockSoliplexHttpClient extends Mock implements SoliplexHttpClient {}

void main() {
  late MockSoliplexHttpClient mockClient;
  late SoliplexHttpAdapter adapter;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockSoliplexHttpClient();
    adapter = SoliplexHttpAdapter(mockClient);
  });

  tearDown(() {
    reset(mockClient);
  });

  StreamedHttpResponse streamResponse({
    int statusCode = 200,
    Map<String, String> headers = const {},
  }) {
    return StreamedHttpResponse(
      statusCode: statusCode,
      body: const Stream.empty(),
      headers: headers,
    );
  }

  group('SoliplexHttpAdapter', () {
    test('sends empty body as null', () async {
      when(
        () => mockClient.requestStream(
          any(),
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => streamResponse());

      final request = http.Request('GET', Uri.parse('https://example.com/api'));
      await adapter.send(request);

      final captured = verify(
        () => mockClient.requestStream(
          'GET',
          Uri.parse('https://example.com/api'),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;

      expect(captured.single, isNull);
    });

    test('sends non-empty body as bytes', () async {
      when(
        () => mockClient.requestStream(
          any(),
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => streamResponse());

      final request = http.Request(
        'POST',
        Uri.parse('https://example.com/api'),
      )..body = '{"key":"value"}';
      await adapter.send(request);

      final captured = verify(
        () => mockClient.requestStream(
          'POST',
          Uri.parse('https://example.com/api'),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;

      expect(captured.single, isNotNull);
      expect(captured.single, isA<List<int>>());
    });

    test('forwards headers from request', () async {
      when(
        () => mockClient.requestStream(
          any(),
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => streamResponse());

      final request = http.Request('GET', Uri.parse('https://example.com/api'))
        ..headers['x-custom'] = 'value';
      await adapter.send(request);

      final captured = verify(
        () => mockClient.requestStream(
          any(),
          any(),
          headers: captureAny(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).captured;

      expect(
        (captured.single as Map<String, String>)['x-custom'],
        equals('value'),
      );
    });

    test('maps response status code and headers', () async {
      when(
        () => mockClient.requestStream(
          any(),
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => streamResponse(
          statusCode: 201,
          headers: {'x-response': 'header'},
        ),
      );

      final request = http.Request('POST', Uri.parse('https://example.com'));
      final response = await adapter.send(request);

      expect(response.statusCode, 201);
      expect(response.headers['x-response'], 'header');
    });

    test('streams response body from inner client', () async {
      final controller = StreamController<List<int>>();
      when(
        () => mockClient.requestStream(
          any(),
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => StreamedHttpResponse(
          statusCode: 200,
          body: controller.stream,
        ),
      );

      final request = http.Request('GET', Uri.parse('https://example.com'));
      final response = await adapter.send(request);

      // Start collecting bytes before adding data to avoid buffering issues.
      final bodyFuture = response.stream.toBytes();
      controller.add([72, 101, 108, 108, 111]); // "Hello"
      await controller.close();

      final body = await bodyFuture;
      expect(body, [72, 101, 108, 108, 111]);
    });
  });
}
