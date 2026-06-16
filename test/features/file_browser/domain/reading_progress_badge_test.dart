import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/domain/reading_progress_badge.dart';

void main() {
  group('parseEpisodeNumber', () {
    test('parses the leading digits of a downloaded file name', () {
      expect(parseEpisodeNumber('003_chapter3.txt'), 3);
      expect(parseEpisodeNumber('012_chapter12.txt'), 12);
      expect(parseEpisodeNumber('1_.txt'), 1);
    });

    test('returns 0 when there is no leading number', () {
      expect(parseEpisodeNumber('chapter.txt'), 0);
      expect(parseEpisodeNumber('_001.txt'), 0);
      expect(parseEpisodeNumber(''), 0);
    });
  });

  group('ReadingProgressBadge.from', () {
    test('reading-in-progress: read derived from file name, total from count',
        () {
      final badge = ReadingProgressBadge.from(
        episodeCount: 120,
        fileName: '003_chapter3.txt',
      );
      expect(badge.read, 3);
      expect(badge.total, 120);
      expect(badge.fraction, closeTo(3 / 120, 1e-9));
    });

    test('unread (no progress row): 0 / N with a 0% bar', () {
      final badge = ReadingProgressBadge.from(
        episodeCount: 80,
        fileName: null,
      );
      expect(badge.read, 0);
      expect(badge.total, 80);
      expect(badge.fraction, 0.0);
    });

    test('robust to a file name with no leading number', () {
      final badge = ReadingProgressBadge.from(
        episodeCount: 50,
        fileName: 'chapter.txt',
      );
      expect(badge.read, 0);
      expect(badge.total, 50);
    });

    test('fraction is 0 when total is 0 (no division by zero)', () {
      final badge = ReadingProgressBadge.from(
        episodeCount: 0,
        fileName: '003_chapter3.txt',
      );
      expect(badge.total, 0);
      expect(badge.fraction, 0.0);
    });

    test('fraction is clamped to 1.0 when read exceeds total', () {
      final badge = ReadingProgressBadge.from(
        episodeCount: 5,
        fileName: '009_chapter9.txt',
      );
      expect(badge.read, 9);
      expect(badge.total, 5);
      expect(badge.fraction, 1.0);
    });
  });
}
