import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/context_chunker.dart';

void main() {
  group('ContextChunker', () {
    test('returns single chunk when total is within limit', () {
      final contexts = ['短いテキスト1', '短いテキスト2', '短いテキスト3'];
      final chunks = ContextChunker.split(contexts);

      expect(chunks.length, 1);
      expect(chunks[0], contexts);
    });

    test('splits contexts into multiple chunks at context boundaries', () {
      // Create contexts that together exceed 4000 chars
      final contexts = List.generate(
        10,
        (i) => 'コンテキスト$i: ${'あ' * 500}',
      );

      final chunks = ContextChunker.split(contexts);

      expect(chunks.length, greaterThan(1));
      // Verify no context is split across chunks
      final allContexts = chunks.expand((c) => c).toList();
      expect(allContexts, contexts);
    });

    test('places large single entry in its own chunk', () {
      final largeEntry = 'あ' * 5000;
      final contexts = ['短いテキスト', largeEntry, '別の短いテキスト'];

      final chunks = ContextChunker.split(contexts);

      // The large entry should be in its own chunk
      final chunkWithLarge =
          chunks.where((c) => c.contains(largeEntry)).toList();
      expect(chunkWithLarge.length, 1);
      expect(chunkWithLarge[0], [largeEntry]);
    });

    test('returns empty list for empty input', () {
      final chunks = ContextChunker.split([]);
      expect(chunks, isEmpty);
    });

    test('handles single context within limit', () {
      final chunks = ContextChunker.split(['短いテキスト']);
      expect(chunks.length, 1);
      expect(chunks[0], ['短いテキスト']);
    });

    test('respects custom chunk size', () {
      final contexts = ['あ' * 100, 'い' * 100, 'う' * 100];
      final chunks = ContextChunker.split(contexts, maxChunkSize: 150);

      expect(chunks.length, 3);
    });
  });
}
