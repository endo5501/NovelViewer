import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';

void main() {
  group('File naming convention', () {
    test('single digit total uses no padding', () {
      expect(formatEpisodeFileName(1, '第一話', 9), '1_第一話.txt');
      expect(formatEpisodeFileName(9, '第九話', 9), '9_第九話.txt');
    });

    test('double digit total uses 2-digit padding', () {
      expect(formatEpisodeFileName(1, '第一話', 99), '01_第一話.txt');
      expect(formatEpisodeFileName(10, '第十話', 99), '10_第十話.txt');
    });

    test('triple digit total uses 3-digit padding', () {
      expect(formatEpisodeFileName(1, '第一話', 100), '001_第一話.txt');
      expect(formatEpisodeFileName(42, '第四十二話', 100), '042_第四十二話.txt');
      expect(formatEpisodeFileName(100, '最終話', 100), '100_最終話.txt');
    });

    test('four digit total uses 4-digit padding', () {
      expect(formatEpisodeFileName(1, '序章', 1500), '0001_序章.txt');
    });

    test('sanitizes invalid characters in title', () {
      expect(
        formatEpisodeFileName(1, '第一話:始まり', 10),
        '01_第一話_始まり.txt',
      );
      expect(
        formatEpisodeFileName(1, 'test/name', 10),
        '01_test_name.txt',
      );
      expect(
        formatEpisodeFileName(1, 'a*b?c', 10),
        '01_a_b_c.txt',
      );
    });

    test('preserves Japanese characters in title', () {
      expect(
        formatEpisodeFileName(1, 'プロローグ～始まりの日～', 10),
        '01_プロローグ～始まりの日～.txt',
      );
    });

    test('trims and normalizes whitespace in title', () {
      expect(
        formatEpisodeFileName(1, '  第一話   始まり  ', 10),
        '01_第一話 始まり.txt',
      );
    });
  });
}
