import 'package:flutter/foundation.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

/// Collects HTTP events for the network inspector UI.
class NetworkInspector
    with ChangeNotifier
    implements HttpObserver, ConcurrencyObserver {
  final List<HttpEvent> _events = [];
  final List<HttpConcurrencyWaitEvent> _concurrencyEvents = [];

  List<HttpEvent> get events => List.unmodifiable(_events);

  List<HttpConcurrencyWaitEvent> get concurrencyEvents =>
      List.unmodifiable(_concurrencyEvents);

  void clear() {
    _events.clear();
    _concurrencyEvents.clear();
    notifyListeners();
  }

  void _add(HttpEvent event) {
    _events.add(event);
    notifyListeners();
  }

  @override
  void onRequest(HttpRequestEvent event) => _add(event);

  @override
  void onResponse(HttpResponseEvent event) => _add(event);

  @override
  void onError(HttpErrorEvent event) => _add(event);

  @override
  void onStreamStart(HttpStreamStartEvent event) => _add(event);

  @override
  void onStreamEnd(HttpStreamEndEvent event) => _add(event);

  @override
  void onConcurrencyWait(HttpConcurrencyWaitEvent event) {
    _concurrencyEvents.add(event);
    notifyListeners();
  }
}
