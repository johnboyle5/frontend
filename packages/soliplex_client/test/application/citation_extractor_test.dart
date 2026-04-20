import 'package:soliplex_client/src/application/citation_extractor.dart';
import 'package:soliplex_client/src/schema/agui_features/rag.dart';
import 'package:test/test.dart';

void main() {
  group('CitationExtractor', () {
    late CitationExtractor extractor;

    setUp(() {
      extractor = CitationExtractor();
    });

    group('extractNew', () {
      Map<String, dynamic> createCitation({
        required String chunkId,
        String content = 'test content',
        String documentId = 'doc-1',
        String documentUri = 'https://example.com/doc.pdf',
        String? documentTitle,
        List<String>? headings,
        List<int>? pageNumbers,
        int? index,
      }) {
        return {
          'chunk_id': chunkId,
          'content': content,
          'document_id': documentId,
          'document_uri': documentUri,
          if (documentTitle != null) 'document_title': documentTitle,
          if (headings != null) 'headings': headings,
          if (pageNumbers != null) 'page_numbers': pageNumbers,
          if (index != null) 'index': index,
        };
      }

      /// Builds a RAG-namespaced state with the new shape: `citation_index`
      /// (id → Citation) and `citations` (per-turn list of id lists).
      Map<String, dynamic> createState({
        Map<String, Map<String, dynamic>> citationIndex = const {},
        List<List<String>> citations = const [],
      }) {
        return {
          'rag': {
            'citation_index': citationIndex,
            'citations': citations,
          },
        };
      }

      test('returns empty when no state change', () {
        final state = createState(
          citationIndex: {'c1': createCitation(chunkId: 'c1')},
          citations: [
            ['c1'],
          ],
        );

        final refs = extractor.extractNew(state, state);

        expect(refs, isEmpty);
      });

      test('returns empty when previous state is empty', () {
        final previous = createState();
        final current = createState();

        final refs = extractor.extractNew(previous, current);

        expect(refs, isEmpty);
      });

      test('extracts citations from new turn', () {
        final previous = createState();
        final current = createState(
          citationIndex: {
            'chunk-1': createCitation(
              chunkId: 'chunk-1',
              content: 'Citation content',
              documentTitle: 'Test Doc',
              headings: ['Chapter 1'],
              pageNumbers: [1, 2],
              index: 1,
            ),
          },
          citations: [
            ['chunk-1'],
          ],
        );

        final refs = extractor.extractNew(previous, current);

        expect(refs, hasLength(1));
        expect(refs[0].chunkId, 'chunk-1');
        expect(refs[0].content, 'Citation content');
        expect(refs[0].documentId, 'doc-1');
        expect(refs[0].documentUri, 'https://example.com/doc.pdf');
        expect(refs[0].documentTitle, 'Test Doc');
        expect(refs[0].headings, ['Chapter 1']);
        expect(refs[0].pageNumbers, [1, 2]);
        expect(refs[0].index, 1);
      });

      test('defaults headings and pageNumbers to empty lists when absent', () {
        final previous = createState();
        final current = createState(
          citationIndex: {'c1': createCitation(chunkId: 'c1')},
          citations: [
            ['c1'],
          ],
        );

        final refs = extractor.extractNew(previous, current);

        expect(refs, hasLength(1));
        expect(refs[0].headings, isEmpty);
        expect(refs[0].pageNumbers, isEmpty);
      });

      test('extracts only new turns when citations grows', () {
        final previous = createState(
          citationIndex: {'old-chunk': createCitation(chunkId: 'old-chunk')},
          citations: [
            ['old-chunk'],
          ],
        );
        final current = createState(
          citationIndex: {
            'old-chunk': createCitation(chunkId: 'old-chunk'),
            'new-chunk': createCitation(chunkId: 'new-chunk'),
          },
          citations: [
            ['old-chunk'],
            ['new-chunk'],
          ],
        );

        final refs = extractor.extractNew(previous, current);

        expect(refs, hasLength(1));
        expect(refs[0].chunkId, 'new-chunk');
      });

      test('extracts multiple citations from a single new turn', () {
        final previous = createState();
        final current = createState(
          citationIndex: {
            'chunk-1': createCitation(chunkId: 'chunk-1'),
            'chunk-2': createCitation(chunkId: 'chunk-2'),
            'chunk-3': createCitation(chunkId: 'chunk-3'),
          },
          citations: [
            ['chunk-1', 'chunk-2', 'chunk-3'],
          ],
        );

        final refs = extractor.extractNew(previous, current);

        expect(refs, hasLength(3));
        expect(refs.map((r) => r.chunkId), ['chunk-1', 'chunk-2', 'chunk-3']);
      });

      test('handles turn with no citations', () {
        final previous = createState();
        final current = createState(
          citations: [
            <String>[],
          ],
        );

        final refs = extractor.extractNew(previous, current);

        expect(refs, isEmpty);
      });

      test('extracts citations from STATE_DELTA with minimal keys', () {
        final previous = createState();
        final current = <String, dynamic>{
          'rag': {
            'citation_index': {'c1': createCitation(chunkId: 'c1')},
            'citations': [
              ['c1'],
            ],
          },
        };

        final refs = extractor.extractNew(previous, current);

        expect(refs, hasLength(1));
        expect(refs[0].chunkId, 'c1');
      });

      test('skips citation ids missing from the registry', () {
        final previous = createState();
        final current = createState(
          citationIndex: {'c1': createCitation(chunkId: 'c1')},
          citations: [
            ['c1', 'missing'],
          ],
        );

        final refs = extractor.extractNew(previous, current);

        expect(refs, hasLength(1));
        expect(refs[0].chunkId, 'c1');
      });
    });

    group('edge cases', () {
      test('returns empty for unknown state format', () {
        final previous = <String, dynamic>{};
        final current = <String, dynamic>{'unknown_key': <String, dynamic>{}};

        final refs = extractor.extractNew(previous, current);

        expect(refs, isEmpty);
      });

      test('returns empty when current has fewer turns than previous', () {
        // This can happen with FIFO rotation
        final previous = <String, dynamic>{
          'rag': {
            'citation_index': <String, dynamic>{},
            'citations': [
              <String>[],
              <String>[],
            ],
          },
        };
        final current = <String, dynamic>{
          'rag': {
            'citation_index': <String, dynamic>{},
            'citations': [
              <String>[],
            ],
          },
        };

        final refs = extractor.extractNew(previous, current);

        expect(refs, isEmpty);
      });

      test('returns empty when new turn has no citations', () {
        final previous = <String, dynamic>{};
        final current = <String, dynamic>{
          'rag': {
            'citation_index': <String, dynamic>{},
            'citations': [
              <String>[],
            ],
          },
        };

        final refs = extractor.extractNew(previous, current);
        expect(refs, isEmpty);
      });

      test('returns empty when rag key is not a Map', () {
        final previous = <String, dynamic>{};
        final current = <String, dynamic>{'rag': 'not a map'};

        final refs = extractor.extractNew(previous, current);
        expect(refs, isEmpty);
      });

      test('returns empty when previous rag key is not a Map', () {
        final previous = <String, dynamic>{'rag': 42};
        final current = <String, dynamic>{
          'rag': {
            'citation_index': <String, dynamic>{},
            'citations': [
              <String>[],
            ],
          },
        };

        // Treats previous as empty (length 0); new turn has no citation ids.
        final refs = extractor.extractNew(previous, current);
        expect(refs, isEmpty);
      });

      test('returns empty when citations is not a List', () {
        final previous = <String, dynamic>{};
        final current = <String, dynamic>{
          'rag': {'citations': 'not a list'},
        };

        // citations length treated as 0 for both, no growth detected
        final refs = extractor.extractNew(previous, current);
        expect(refs, isEmpty);
      });

      test('returns empty on malformed turn entry', () {
        final previous = <String, dynamic>{};
        final current = <String, dynamic>{
          'rag': {
            'citation_index': <String, dynamic>{},
            'citations': [
              'not-a-list',
            ],
          },
        };

        final refs = extractor.extractNew(previous, current);
        expect(refs, isEmpty);
      });
    });

    test('knownRagKeys matches Rag schema keys', () {
      final schemaKeys = Rag().toJson().keys.toSet();
      expect(
        schemaKeys,
        equals(knownRagKeys),
        reason: 'knownRagKeys must stay in sync with Rag schema fields',
      );
    });
  });
}
