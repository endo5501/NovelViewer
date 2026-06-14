import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/episode/episode_resolver.dart';
import 'package:path/path.dart' as p;

void main() {
  group('listSortedTextFileNames', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('episode_resolver_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns directly-nested .txt files in lexical order', () async {
      await File(p.join(tempDir.path, '030_c.txt')).writeAsString('c');
      await File(p.join(tempDir.path, '010_a.txt')).writeAsString('a');
      await File(p.join(tempDir.path, '020_b.txt')).writeAsString('b');
      await File(p.join(tempDir.path, 'note.md')).writeAsString('m');

      expect(
        listSortedTextFileNames(tempDir.path),
        ['010_a.txt', '020_b.txt', '030_c.txt'],
      );
    });

    test('returns empty list for a non-existent directory', () {
      final missing = p.join(tempDir.path, 'does_not_exist');
      expect(listSortedTextFileNames(missing), isEmpty);
    });

    test('matches the .txt extension case-insensitively', () async {
      await File(p.join(tempDir.path, '001.TXT')).writeAsString('x');
      expect(listSortedTextFileNames(tempDir.path), ['001.TXT']);
    });

    test('does not invoke onError on the happy path', () async {
      await File(p.join(tempDir.path, '001.txt')).writeAsString('x');
      var errors = 0;
      listSortedTextFileNames(tempDir.path, onError: (_, _) => errors++);
      expect(errors, 0);
    });

    test('does not invoke onError for a non-existent directory', () {
      var errors = 0;
      listSortedTextFileNames(
        p.join(tempDir.path, 'missing'),
        onError: (_, _) => errors++,
      );
      expect(errors, 0,
          reason: 'a missing directory returns empty without erroring');
    });
  });

  group('extractNumericPrefix', () {
    test('returns the leading numeric prefix when present', () {
      expect(extractNumericPrefix('040_chapter.txt'), 40);
    });

    test('returns null when there is no leading digit run', () {
      expect(extractNumericPrefix('prologue.txt'), isNull);
    });

    test('handles leading zeros', () {
      expect(extractNumericPrefix('007_x.txt'), 7);
    });

    test('returns null for a digit run that overflows 64-bit int', () {
      // A pathological file name must not crash the resolver with a
      // FormatException; it degrades to "no numeric prefix".
      expect(extractNumericPrefix('${'9' * 20}_x.txt'), isNull);
    });
  });

  group('lexicalRankOf', () {
    test('returns the 1-origin rank within the listing', () {
      expect(lexicalRankOf(const ['a.txt', 'b.txt', 'c.txt'], 'b.txt'), 2);
    });

    test('returns null when not found', () {
      expect(lexicalRankOf(const ['a.txt'], 'z.txt'), isNull);
    });

    test('returns null for an empty listing', () {
      expect(lexicalRankOf(const [], 'a.txt'), isNull);
    });
  });

  group('effectiveEpisodeOrNull (scope-filter rule, no fallback)', () {
    test('uses the numeric prefix when present', () {
      expect(
        effectiveEpisodeOrNull('040_chapter.txt', const ['040_chapter.txt']),
        40,
      );
    });

    test('falls back to lexical rank within the full folder listing', () {
      const folder = ['intro.txt', 'part1.txt', 'part2.txt'];
      expect(effectiveEpisodeOrNull('part2.txt', folder), 3);
    });

    test('returns null when prefix-less and not present in the folder', () {
      expect(effectiveEpisodeOrNull('ghost.txt', const ['intro.txt']), isNull);
    });
  });

  group('resolveCurrentFileEpisode (ネタバレなし上限, fallback 1)', () {
    test('returns the prefix without listing the folder', () {
      var listed = false;
      final bound = resolveCurrentFileEpisode(
        fileName: '040_chapter.txt',
        folderFiles: () {
          listed = true;
          return const [];
        },
      );
      expect(bound, 40);
      expect(listed, isFalse,
          reason: 'prefix-present files must not trigger a directory listing');
    });

    test('uses lexical rank for a prefix-less current file', () {
      final bound = resolveCurrentFileEpisode(
        fileName: 'intro.txt',
        folderFiles: () => const ['intro.txt', 'part1.txt', 'part2.txt'],
      );
      expect(bound, 1);
    });

    test('falls back to 1 when the folder cannot be listed', () {
      final bound = resolveCurrentFileEpisode(
        fileName: 'intro.txt',
        folderFiles: () => const [],
      );
      expect(bound, 1);
    });
  });

  group('resolveUpperBoundForAllFiles (ネタバレあり上限)', () {
    test('returns the highest prefix for a fully-numbered folder', () {
      final files = [
        for (var i = 1; i <= 120; i++) '${i.toString().padLeft(3, '0')}_c.txt'
      ];
      expect(resolveUpperBoundForAllFiles(files), 120);
    });

    test('uses file count when it exceeds the highest prefix (mixed folder)',
        () {
      final files = [
        for (var i = 1; i <= 40; i++) '${i.toString().padLeft(3, '0')}_c.txt',
        'afterword.txt',
        'prologue.txt',
      ];
      expect(resolveUpperBoundForAllFiles(files), 42,
          reason: 'max(highest prefix 40, total count 42) = 42');
    });

    test('returns 1 for an empty folder', () {
      expect(resolveUpperBoundForAllFiles(const []), 1);
    });
  });

  group('resolveSourceFileForAllFiles (jump link target)', () {
    test('prefers the highest-prefix file', () {
      expect(
        resolveSourceFileForAllFiles(
            const ['010_a.txt', '100_c.txt', '020_b.txt']),
        '100_c.txt',
      );
    });

    test('falls back to the last lexical file when no prefix exists', () {
      expect(
        resolveSourceFileForAllFiles(const ['part1.txt', 'part2.txt']),
        'part2.txt',
      );
    });

    test('returns null for an empty folder', () {
      expect(resolveSourceFileForAllFiles(const []), isNull);
    });
  });
}
