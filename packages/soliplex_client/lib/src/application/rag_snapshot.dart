import 'package:soliplex_client/src/schema/agui_features/rag.dart';
// ignore: unused_import  — imported for doc references in this file.
import 'package:soliplex_client/src/schema/agui_features/rag_v040.dart';

/// The AG-UI state namespace key for RAG state.
///
/// Must match the backend's `STATE_NAMESPACE` in `haiku.rag.skills.rag`.
const ragStateKey = 'rag';

/// Version-agnostic view of the backend's `rag`-namespaced AG-UI state.
///
/// The backend ships two wire shapes today:
///
/// - **haiku.rag 0.40** emits `citations` as a list of inline [Citation]
///   objects, alongside deprecated `qa_history`, `documents`, and
///   `reports` fields. See `rag_v040.dart`.
/// - **haiku.rag 0.42+** emits `citations` as a list of chunk ids, with a
///   separate `citation_index` map resolving each id to a [Citation]. See
///   `rag.dart` (the generated schema).
///
/// [RagSnapshot.fromJson] dispatches on wire shape today because the
/// backend has no explicit `schema_version` field. When that field is
/// added, only [RagSnapshot.fromJson] needs to change — everything above
/// this interface continues to depend on the two operations below and is
/// unaffected.
///
/// Version-specific fields (e.g. `qaHistory` on 0.40, `searches` on either
/// version) are reachable via the concrete schema types
/// ([RagV040] in `rag_v040.dart`, [Rag] in `rag.dart`) and are out of
/// scope for this interface until a consumer needs them.
abstract class RagSnapshot {
  /// Chunk ids of citations present in the current state. Under 0.42
  /// lifecycle these are cleared at each invocation start; under 0.40
  /// they accumulate across the thread.
  List<String> get citationIds;

  /// Resolves a chunk id to a full [Citation], or null if not present.
  Citation? resolveCitation(String id);

  /// Parses a `rag`-namespaced state map into the appropriate variant.
  ///
  /// Detection is shape-based today. When the backend adds a
  /// `schema_version` field the body of this factory becomes a switch on
  /// that field, with shape-sniffing retained only as a legacy fallback.
  static RagSnapshot fromJson(Map<String, dynamic> json) {
    return _isV040(json)
        ? RagV040Snapshot.fromJson(json)
        : RagV042Snapshot.fromJson(json);
  }
}

/// Returns true if [json] carries the 0.40 RAG state shape.
///
/// Signals, in order of decisiveness:
/// 1. `citations` is a non-empty list whose first element is a Map —
///    conclusive, since 0.42's `citations` holds strings.
/// 2. `citation_index` is present — conclusive for 0.42 (0.40 has no
///    such field).
/// 3. Any of `qa_history`, `documents`, `reports` is present —
///    0.40-exclusive fields (removed in 0.42). Covers cases where
///    `citations` is empty/absent.
/// 4. Default to 0.42 (the target schema).
bool _isV040(Map<String, dynamic> json) {
  final citations = json['citations'];
  if (citations is List && citations.isNotEmpty && citations.first is Map) {
    return true;
  }
  if (json.containsKey('citation_index')) return false;
  if (json.containsKey('qa_history') ||
      json.containsKey('documents') ||
      json.containsKey('reports')) {
    return true;
  }
  return false;
}

/// [RagSnapshot] backed by the haiku.rag 0.40 wire shape.
///
/// The snapshot deliberately consumes only `citations` (as a list of
/// inline [Citation] objects). Other 0.40 fields are accessible via
/// `RagV040.fromJson` in `rag_v040.dart`.
class RagV040Snapshot implements RagSnapshot {
  RagV040Snapshot._(this._byId);

  /// Parses inline Citations from 0.40-shaped JSON. Malformed entries
  /// (non-Map or invalid Citation payloads) are skipped.
  factory RagV040Snapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['citations'];
    final byId = <String, Citation>{};
    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          final citation = Citation.fromJson(entry);
          byId[citation.chunkId] = citation;
        } on Object {
          // Malformed individual entries are skipped; the snapshot
          // represents a best-effort view of a state that may be mid-delta
          // or carrying schema drift.
        }
      }
    }
    return RagV040Snapshot._(byId);
  }

  final Map<String, Citation> _byId;

  @override
  List<String> get citationIds => _byId.keys.toList();

  @override
  Citation? resolveCitation(String id) => _byId[id];
}

/// [RagSnapshot] backed by the haiku.rag 0.42 wire shape.
///
/// Delegates parsing to the generated [Rag] class and exposes only the
/// citation-resolution surface. Other 0.42 fields (`document_filter`,
/// `searches`) are accessible via `Rag.fromJson` in `rag.dart`.
class RagV042Snapshot implements RagSnapshot {
  RagV042Snapshot._(this._citationIds, this._index);

  /// Parses a 0.42-shaped payload via the generated [Rag] class, keeping
  /// the lookup surface the extractor needs.
  factory RagV042Snapshot.fromJson(Map<String, dynamic> json) {
    final rag = Rag.fromJson(json);
    return RagV042Snapshot._(
      rag.citations ?? const [],
      rag.citationIndex ?? const {},
    );
  }

  final List<String> _citationIds;
  final Map<String, Citation> _index;

  @override
  List<String> get citationIds => _citationIds;

  @override
  Citation? resolveCitation(String id) => _index[id];
}
