import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';

FactCacheEntry _entry({
  required String contentHash,
  required int promptVersion,
}) {
  return FactCacheEntry(
    word: 'アリス',
    fileName: '005.txt',
    facts: '- 事実',
    contentHash: contentHash,
    promptVersion: promptVersion,
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  group('computeContentHash', () {
    test('is deterministic for the same content', () {
      expect(computeContentHash('アリスの章'), computeContentHash('アリスの章'));
    });

    test('differs when content changes', () {
      expect(
        computeContentHash('アリスの章'),
        isNot(computeContentHash('アリスの章（改稿）')),
      );
    });
  });

  group('isFactCacheValid', () {
    const promptVersion = FactCacheRepository.currentPromptVersion;
    final hash = computeContentHash('episode body');

    test('null entry is invalid', () {
      expect(
        isFactCacheValid(null,
            currentHash: hash, currentPromptVersion: promptVersion),
        isFalse,
      );
    });

    test('matching hash and prompt version is valid', () {
      expect(
        isFactCacheValid(
          _entry(contentHash: hash, promptVersion: promptVersion),
          currentHash: hash,
          currentPromptVersion: promptVersion,
        ),
        isTrue,
      );
    });

    test('content hash mismatch is invalid', () {
      expect(
        isFactCacheValid(
          _entry(contentHash: 'stale', promptVersion: promptVersion),
          currentHash: hash,
          currentPromptVersion: promptVersion,
        ),
        isFalse,
      );
    });

    test('prompt version mismatch is invalid even if hash matches', () {
      expect(
        isFactCacheValid(
          _entry(contentHash: hash, promptVersion: promptVersion + 1),
          currentHash: hash,
          currentPromptVersion: promptVersion,
        ),
        isFalse,
      );
    });

    test('empty-string sentinel hash is always invalid', () {
      expect(
        isFactCacheValid(
          _entry(
              contentHash: FactCacheRepository.sentinelHash,
              promptVersion: promptVersion),
          currentHash: FactCacheRepository.sentinelHash,
          currentPromptVersion: promptVersion,
        ),
        isFalse,
        reason: 'sentinel must not be reusable even if currentHash is empty',
      );
    });
  });
}
