import 'dart:async' show unawaited;
import 'dart:developer' as dev;

import 'package:signals_flutter/signals_flutter.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Sealed status for a single upload scope (a room or a thread).
///
/// `Loaded` once the server list is known (even if empty). `Failed`
/// only from a non-`Loaded` baseline — a refresh failure preserves
/// the prior `Loaded` list and logs.
sealed class UploadsStatus {
  const UploadsStatus();
}

class UploadsLoading extends UploadsStatus {
  const UploadsLoading();
}

class UploadsLoaded extends UploadsStatus {
  const UploadsLoaded(this.uploads);
  final List<DisplayUpload> uploads;
}

class UploadsFailed extends UploadsStatus {
  const UploadsFailed(this.error);
  final Object error;
}

/// Sealed display variant for a single row in the merged uploads list.
///
/// Persisted rows come from the server LIST endpoint; Pending and
/// Failed rows are local optimistic entries driven by in-flight or
/// recently-failed POST uploads.
sealed class DisplayUpload {
  const DisplayUpload({required this.filename});
  final String filename;
}

class PersistedUpload extends DisplayUpload {
  const PersistedUpload({required super.filename, required this.url});
  final Uri url;
}

class PendingUpload extends DisplayUpload {
  const PendingUpload({required this.id, required super.filename});
  final String id;
}

class FailedUpload extends DisplayUpload {
  const FailedUpload({
    required this.id,
    required super.filename,
    required this.message,
  });
  final String id;
  final String message;
}

/// Formats an error for user display without leaking raw exception
/// internals (stack frames, request URLs, auth headers). Extracts the
/// message from known [SoliplexException] subtypes; falls back to a
/// fixed, translatable string for anything else.
String uploadErrorMessage(Object error) {
  if (error is SoliplexException) return error.message;
  return 'Something went wrong. Please try again.';
}

/// Internal record for a local upload row. Sealed so pending/failed
/// states each carry exactly the fields they need — a pending record
/// cannot accidentally hold an error message, and a failed record
/// cannot lack one. Failed rows replace pending rows by index in the
/// `_pending` list rather than mutate in place.
sealed class _PendingRecord {
  const _PendingRecord({required this.id, required this.filename});
  final String id;
  final String filename;
}

class _Pending extends _PendingRecord {
  const _Pending({required super.id, required super.filename});
}

class _Failed extends _PendingRecord {
  const _Failed({
    required super.id,
    required super.filename,
    required this.message,
  });
  final String message;
}

class _ScopeState {
  _ScopeState() : signal = Signal<UploadsStatus>(const UploadsLoading());

  List<FileUpload>? persisted;
  final List<_PendingRecord> pending = [];
  CancelToken? fetchToken;
  final Signal<UploadsStatus> signal;

  void dispose() {
    fetchToken?.cancel('disposed');
    signal.dispose();
  }
}

/// Tracks file uploads across rooms and threads, merging a
/// server-fetched list with an in-flight optimistic view.
///
/// Owned by `UploadTrackerRegistry`, not by any single widget, so
/// uploads started on one screen survive when the user navigates away
/// before the POST resolves.
class UploadTracker {
  UploadTracker({required SoliplexApi api}) : _api = api;

  final SoliplexApi _api;
  final Map<String, _ScopeState> _scopes = {};
  bool _isDisposed = false;
  int _nextId = 0;

  static String _roomKey(String roomId) => 'room:$roomId';
  static String _threadKey(String roomId, String threadId) =>
      'thread:$roomId:$threadId';

  _ScopeState _scope(String key) => _scopes.putIfAbsent(key, _ScopeState.new);

  // --------------------------------------------------------
  // Public signals
  // --------------------------------------------------------

  ReadonlySignal<UploadsStatus> roomUploads(String roomId) =>
      _scope(_roomKey(roomId)).signal;

  ReadonlySignal<UploadsStatus> threadUploads(
    String roomId,
    String threadId,
  ) =>
      _scope(_threadKey(roomId, threadId)).signal;

  // --------------------------------------------------------
  // Fetch triggers
  // --------------------------------------------------------

  /// Fetches the room's upload list on first call; subsequent calls
  /// are no-ops while the scope is already Loaded (use [refreshRoom]
  /// to force a reload).
  void fetchRoomUploads(String roomId) {
    _ensureFetched(
      key: _roomKey(roomId),
      fetch: (token) => _api.getRoomUploads(roomId, cancelToken: token),
    );
  }

  void fetchThreadUploads(String roomId, String threadId) {
    _ensureFetched(
      key: _threadKey(roomId, threadId),
      fetch: (token) =>
          _api.getThreadUploads(roomId, threadId, cancelToken: token),
    );
  }

  Future<void> refreshRoom(String roomId) {
    return _refresh(
      key: _roomKey(roomId),
      fetch: (token) => _api.getRoomUploads(roomId, cancelToken: token),
    );
  }

  Future<void> refreshThread(String roomId, String threadId) {
    return _refresh(
      key: _threadKey(roomId, threadId),
      fetch: (token) =>
          _api.getThreadUploads(roomId, threadId, cancelToken: token),
    );
  }

  void _ensureFetched({
    required String key,
    required Future<List<FileUpload>> Function(CancelToken) fetch,
  }) {
    if (_isDisposed) return;
    final scope = _scope(key);
    if (scope.signal.value is UploadsLoaded) return;
    unawaited(_fetch(scope: scope, fetch: fetch));
  }

  Future<void> _refresh({
    required String key,
    required Future<List<FileUpload>> Function(CancelToken) fetch,
  }) {
    if (_isDisposed) return Future<void>.value();
    return _fetch(scope: _scope(key), fetch: fetch);
  }

  Future<void> _fetch({
    required _ScopeState scope,
    required Future<List<FileUpload>> Function(CancelToken) fetch,
  }) async {
    if (_isDisposed) return;
    scope.fetchToken?.cancel('re-fetch');
    final token = CancelToken();
    scope.fetchToken = token;

    if (scope.signal.value is! UploadsLoaded) {
      scope.signal.value = const UploadsLoading();
    }

    try {
      final list = await fetch(token);
      if (token.isCancelled || _isDisposed) return;
      scope.fetchToken = null;
      scope.persisted = list;
      _emit(scope);
    } on Exception catch (error) {
      if (token.isCancelled || _isDisposed) return;
      scope.fetchToken = null;
      if (scope.signal.value is UploadsLoaded) {
        dev.log(
          'Upload list refresh failed, keeping stale list',
          error: error,
          name: 'UploadTracker',
        );
      } else {
        scope.signal.value = UploadsFailed(error);
      }
    }
  }

  // --------------------------------------------------------
  // Upload actions
  // --------------------------------------------------------

  void uploadToRoom({
    required String roomId,
    required String filename,
    required List<int> fileBytes,
    String mimeType = 'application/octet-stream',
  }) {
    final key = _roomKey(roomId);
    _startUpload(
      key: key,
      filename: filename,
      post: () => _api.uploadFileToRoom(
        roomId,
        filename: filename,
        fileBytes: fileBytes,
        mimeType: mimeType,
      ),
      refresh: () => _refresh(
        key: key,
        fetch: (token) => _api.getRoomUploads(roomId, cancelToken: token),
      ),
    );
  }

  void uploadToThread({
    required String roomId,
    required String threadId,
    required String filename,
    required List<int> fileBytes,
    String mimeType = 'application/octet-stream',
  }) {
    final key = _threadKey(roomId, threadId);
    _startUpload(
      key: key,
      filename: filename,
      post: () => _api.uploadFileToThread(
        roomId,
        threadId,
        filename: filename,
        fileBytes: fileBytes,
        mimeType: mimeType,
      ),
      refresh: () => _refresh(
        key: key,
        fetch: (token) =>
            _api.getThreadUploads(roomId, threadId, cancelToken: token),
      ),
    );
  }

  void _startUpload({
    required String key,
    required String filename,
    required Future<void> Function() post,
    required Future<void> Function() refresh,
  }) {
    if (_isDisposed) return;
    final scope = _scope(key);
    final id = 'upload-${_nextId++}';
    scope.pending.add(_Pending(id: id, filename: filename));
    _emit(scope);

    unawaited(_runUpload(scope: scope, id: id, post: post, refresh: refresh));
  }

  Future<void> _runUpload({
    required _ScopeState scope,
    required String id,
    required Future<void> Function() post,
    required Future<void> Function() refresh,
  }) async {
    try {
      await post();
      if (_isDisposed) return;

      // Refresh BEFORE dropping the pending record so the UI never
      // shows a gap between "Pending" and "Persisted".
      await refresh();
      if (_isDisposed) return;

      scope.pending.removeWhere((r) => r.id == id);
      _emit(scope);
    } on Exception catch (error) {
      if (_isDisposed) return;
      final idx = scope.pending.indexWhere((r) => r.id == id);
      if (idx < 0) {
        // The record was dismissed (or otherwise removed) during the
        // upload — nothing to mark as failed. Log so a future caller
        // removing records by some other mechanism surfaces the
        // swallowed failure.
        dev.log(
          'Upload completed after its pending record was removed',
          error: error,
          name: 'UploadTracker',
        );
        return;
      }
      scope.pending[idx] = _Failed(
        id: id,
        filename: scope.pending[idx].filename,
        message: uploadErrorMessage(error),
      );
      _emit(scope);
    }
  }

  // --------------------------------------------------------
  // Dismissal
  // --------------------------------------------------------

  /// Removes a Pending or Failed entry by its id. Persisted entries
  /// come from the server and cannot be dismissed from the client.
  void dismiss(String entryId) {
    if (_isDisposed) return;
    for (final scope in _scopes.values) {
      final before = scope.pending.length;
      scope.pending.removeWhere((r) => r.id == entryId);
      if (scope.pending.length != before) {
        _emit(scope);
        return;
      }
    }
  }

  // --------------------------------------------------------
  // Signal emission
  // --------------------------------------------------------

  void _emit(_ScopeState scope) {
    if (_isDisposed) return;
    final persisted = scope.persisted;
    final merged = <DisplayUpload>[
      if (persisted != null)
        for (final f in persisted)
          PersistedUpload(filename: f.filename, url: f.url),
      for (final p in scope.pending)
        switch (p) {
          _Pending() => PendingUpload(id: p.id, filename: p.filename),
          _Failed() => FailedUpload(
              id: p.id,
              filename: p.filename,
              message: p.message,
            ),
        },
    ];

    // No server list yet and nothing local: keep the current Loading
    // or Failed status; don't prematurely emit Loaded([]).
    if (persisted == null && merged.isEmpty) return;

    scope.signal.value = UploadsLoaded(List.unmodifiable(merged));
  }

  // --------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final scope in _scopes.values) {
      scope.dispose();
    }
    _scopes.clear();
  }
}
