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
      final contexts = List.generate(10, (i) => 'コンテキスト$i: ${'あ' * 500}');

      final chunks = ContextChunker.split(contexts);

      expect(chunks.length, greaterThan(1));
      // Verify no context is split across chunks
      final allContexts = chunks.expand((c) => c).toList();
      expect(allContexts, contexts);
    });

    test('splits an entry that alone exceeds the limit', () {
      // Left whole, such an entry would be handed to the model in one piece
      // and blow a window the chunk size exists to respect. A novel with long
      // paragraphs produces these.
      final largeEntry = 'あ' * 5000;
      final contexts = ['短いテキスト', largeEntry, '別の短いテキスト'];

      final chunks = ContextChunker.split(contexts);

      for (final chunk in chunks) {
        expect(
          chunk.fold<int>(0, (sum, entry) => sum + entry.length),
          lessThanOrEqualTo(4000),
        );
      }
    });

    test('keeps every character of an entry it had to split', () {
      final largeEntry = List.generate(200, (i) => '第$i文。').join();
      final chunks = ContextChunker.split([largeEntry], maxChunkSize: 100);

      expect(chunks.expand((c) => c).join(), largeEntry);
    });

    test('prefers a line break when it has to cut', () {
      final lines = List.generate(
        40,
        (i) =>
            '${i.toString().padLeft(3, '0')}'
            '${'あ' * 20}',
      );
      final entry = lines.join('\n');

      final chunks = ContextChunker.split([entry], maxChunkSize: 100);

      // No piece starts mid-line: every cut landed on a newline, so the
      // leading fragment of each piece is a whole line.
      for (final piece in chunks.expand((c) => c)) {
        expect(piece.trimLeft().length, greaterThan(0));
        expect(
          lines.any((l) => piece.trimLeft().startsWith(l)),
          isTrue,
          reason: piece.substring(0, 10),
        );
      }
    });

    test('cuts at the limit when there is no line break to prefer', () {
      final entry = 'あ' * 250;

      final chunks = ContextChunker.split([entry], maxChunkSize: 100);

      expect(chunks.expand((c) => c).map((e) => e.length).toList(), [
        100,
        100,
        50,
      ]);
    });

    test('an entry within the limit is never split', () {
      const entry = '短いテキスト';

      final chunks = ContextChunker.split([entry], maxChunkSize: 100);

      expect(chunks, [
        [entry],
      ]);
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
