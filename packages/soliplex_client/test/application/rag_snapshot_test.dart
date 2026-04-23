import 'package:soliplex_client/src/application/rag_snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('RagSnapshot.fromJson detection', () {
    test('detects v040 from Map-shaped citations', () {
      final json = {
        'citations': [
          {
            'chunk_id': 'c1',
            'content': 'text',
            'document_id': 'd1',
            'document_uri': 'uri',
          },
        ],
      };
      final snapshot = RagSnapshot.fromJson(json);
      expect(snapshot, isA<RagV040Snapshot>());
    });

    test('detects v042 from citation_index presence', () {
      final json = <String, dynamic>{
        'citation_index': <String, dynamic>{},
        'citations': <String>[],
      };
      final snapshot = RagSnapshot.fromJson(json);
      expect(snapshot, isA<RagV042Snapshot>());
    });

    test('detects v040 from qa_history presence when citations is empty', () {
      final json = <String, dynamic>{
        'citations': <dynamic>[],
        'qa_history': <dynamic>[],
      };
      expect(RagSnapshot.fromJson(json), isA<RagV040Snapshot>());
    });

    test('detects v040 from documents presence', () {
      final json = <String, dynamic>{'documents': <dynamic>[]};
      expect(RagSnapshot.fromJson(json), isA<RagV040Snapshot>());
    });

    test('detects v040 from reports presence', () {
      final json = <String, dynamic>{'reports': <dynamic>[]};
      expect(RagSnapshot.fromJson(json), isA<RagV040Snapshot>());
    });
  });

  group('RagV040Snapshot behavior', () {
    test('citationIds lists chunk_ids of inline Citations', () {
      final json = {
        'citations': [
          {
            'chunk_id': 'a',
            'content': 't',
            'document_id': 'd',
            'document_uri': 'u',
          },
          {
            'chunk_id': 'b',
            'content': 't',
            'document_id': 'd',
            'document_uri': 'u',
          },
        ],
      };
      final snapshot = RagSnapshot.fromJson(json);
      expect(snapshot.citationIds, equals(['a', 'b']));
    });

    test('resolveCitation returns the inline Citation for a known id', () {
      final json = {
        'citations': [
          {
            'chunk_id': 'a',
            'content': 'content-a',
            'document_id': 'd1',
            'document_uri': 'uri-a',
          },
        ],
      };
      final snapshot = RagSnapshot.fromJson(json);
      final citation = snapshot.resolveCitation('a');
      expect(citation, isNotNull);
      expect(citation!.chunkId, equals('a'));
      expect(citation.content, equals('content-a'));
      expect(citation.documentUri, equals('uri-a'));
    });

    test('resolveCitation returns null for unknown id', () {
      final json = {
        'citations': [
          {
            'chunk_id': 'a',
            'content': 't',
            'document_id': 'd',
            'document_uri': 'u',
          },
        ],
      };
      expect(RagSnapshot.fromJson(json).resolveCitation('missing'), isNull);
    });

    test('tolerates non-Map entries in citations list without crashing', () {
      final json = <String, dynamic>{
        'citations': <dynamic>[
          {
            'chunk_id': 'a',
            'content': 't',
            'document_id': 'd',
            'document_uri': 'u',
          },
          42,
          null,
          'not a citation',
        ],
        // Keep v040 heuristic satisfied — the first Map entry triggers v040.
      };
      final snapshot = RagSnapshot.fromJson(json);
      expect(snapshot.citationIds, equals(['a']));
      expect(snapshot.resolveCitation('a'), isNotNull);
    });

    test(
      'empty citations with qa_history falls back to v040 with empty ids',
      () {
        final json = <String, dynamic>{
          'citations': <dynamic>[],
          'qa_history': <dynamic>[],
        };
        final snapshot = RagSnapshot.fromJson(json);
        expect(snapshot, isA<RagV040Snapshot>());
        expect(snapshot.citationIds, isEmpty);
      },
    );
  });

  group('RagV042Snapshot behavior', () {
    test('citationIds returns the raw string list', () {
      final json = {
        'citation_index': {
          'a': {
            'chunk_id': 'a',
            'content': 't',
            'document_id': 'd',
            'document_uri': 'u',
          },
          'b': {
            'chunk_id': 'b',
            'content': 't',
            'document_id': 'd',
            'document_uri': 'u',
          },
        },
        'citations': ['a', 'b'],
      };
      final snapshot = RagSnapshot.fromJson(json);
      expect(snapshot.citationIds, equals(['a', 'b']));
    });

    test('resolveCitation looks up via citation_index', () {
      final json = {
        'citation_index': {
          'a': {
            'chunk_id': 'a',
            'content': 'content-a',
            'document_id': 'd1',
            'document_uri': 'uri-a',
          },
        },
        'citations': ['a'],
      };
      final snapshot = RagSnapshot.fromJson(json);
      final citation = snapshot.resolveCitation('a');
      expect(citation, isNotNull);
      expect(citation!.content, equals('content-a'));
    });

    test('resolveCitation returns null for ids not in citation_index', () {
      final json = {
        'citation_index': <String, dynamic>{},
        'citations': ['orphan'],
      };
      final snapshot = RagSnapshot.fromJson(json);
      expect(snapshot.resolveCitation('orphan'), isNull);
    });

    test('empty state yields empty citationIds and null resolve', () {
      final snapshot = RagSnapshot.fromJson(<String, dynamic>{});
      expect(snapshot, isA<RagV042Snapshot>());
      expect(snapshot.citationIds, isEmpty);
      expect(snapshot.resolveCitation('any'), isNull);
    });
  });
}
