import 'package:soliplex_agent/soliplex_agent.dart';

HttpRequestEvent createRequestEvent({
  String requestId = 'req-1',
  DateTime? timestamp,
  String method = 'GET',
  Uri? uri,
  Map<String, String> headers = const {},
  dynamic body,
}) {
  return HttpRequestEvent(
    requestId: requestId,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 12),
    method: method,
    uri: uri ?? Uri.parse('http://localhost/api/v1/rooms'),
    headers: headers,
    body: body,
  );
}

HttpResponseEvent createResponseEvent({
  String requestId = 'req-1',
  DateTime? timestamp,
  int statusCode = 200,
  Duration duration = const Duration(milliseconds: 45),
  int bodySize = 1234,
  String? reasonPhrase,
  Map<String, String>? headers,
  dynamic body,
}) {
  return HttpResponseEvent(
    requestId: requestId,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 12),
    statusCode: statusCode,
    duration: duration,
    bodySize: bodySize,
    reasonPhrase: reasonPhrase,
    headers: headers,
    body: body,
  );
}

HttpErrorEvent createErrorEvent({
  String requestId = 'req-1',
  DateTime? timestamp,
  String method = 'POST',
  Uri? uri,
  SoliplexException? exception,
  Duration duration = const Duration(milliseconds: 100),
}) {
  return HttpErrorEvent(
    requestId: requestId,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 12),
    method: method,
    uri: uri ?? Uri.parse('http://localhost/api/v1/rooms'),
    exception:
        exception ?? const NetworkException(message: 'Connection failed'),
    duration: duration,
  );
}

HttpStreamStartEvent createStreamStartEvent({
  String requestId = 'req-1',
  DateTime? timestamp,
  String method = 'POST',
  Uri? uri,
  Map<String, String> headers = const {},
  dynamic body,
}) {
  return HttpStreamStartEvent(
    requestId: requestId,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 12),
    method: method,
    uri: uri ?? Uri.parse('http://localhost/api/v1/rooms'),
    headers: headers,
    body: body,
  );
}

HttpStreamEndEvent createStreamEndEvent({
  String requestId = 'req-1',
  DateTime? timestamp,
  int bytesReceived = 5200,
  Duration duration = const Duration(seconds: 10),
  SoliplexException? error,
  String? body,
}) {
  return HttpStreamEndEvent(
    requestId: requestId,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 12),
    bytesReceived: bytesReceived,
    duration: duration,
    error: error,
    body: body,
  );
}
