import 'package:flutter/foundation.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

/// Collects HTTP events for the network inspector UI.
class NetworkInspector with ChangeNotifier implements HttpObserver {
  final List<HttpEvent> _events = [];

  List<HttpEvent> get events => List.unmodifiable(_events);

  void clear() {
    _events.clear();
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
}
