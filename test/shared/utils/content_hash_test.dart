import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';

void main() {
  group('computeContentHash', () {
    test('returns same hash for same content', () {
      expect(computeContentHash('テスト'), computeContentHash('テスト'));
    });

    test('returns different hashes for different content', () {
      expect(
        computeContentHash('テスト１'),
        isNot(computeContentHash('テスト２')),
      );
    });

    test('returns SHA-256 hex (64 chars)', () {
      expect(computeContentHash('foo').length, 64);
    });
  });
}
