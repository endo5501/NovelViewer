import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

void main() {
  group('resolveNovelId', () {
    const libraryRoot = '/library';

    test('resolves a novel folder directly under the library root', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(
        libraryRoot,
        '/library/narou_n1234ab/001.txt',
        registered,
      );

      expect(result, 'narou_n1234ab');
    });

    test('resolves a novel folder nested under an organizational folder', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(
        libraryRoot,
        '/library/お気に入り/narou_n1234ab/002.txt',
        registered,
      );

      // The first segment is 'お気に入り' (an unregistered organizational
      // folder); the resolver must return the nearest registered leaf name.
      expect(result, 'narou_n1234ab');
    });

    test('picks the nearest registered ancestor in a deep nest', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(
        libraryRoot,
        '/library/A/B/narou_n1234ab/003.txt',
        registered,
      );

      expect(result, 'narou_n1234ab');
    });

    test('resolves when the directory path itself is passed', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(
        libraryRoot,
        '/library/お気に入り/narou_n1234ab',
        registered,
      );

      expect(result, 'narou_n1234ab');
    });

    test('returns null for a path with no registered ancestor folder', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(
        libraryRoot,
        '/library/お気に入り/未整理メモ.txt',
        registered,
      );

      // Must NOT fall back to the first segment 'お気に入り'.
      expect(result, isNull);
    });

    test('returns null when the path is the library root itself', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(libraryRoot, '/library', registered);

      expect(result, isNull);
    });

    test('returns null for a path outside the library root', () {
      final registered = {'narou_n1234ab'};

      final result = resolveNovelId(
        libraryRoot,
        '/elsewhere/narou_n1234ab/001.txt',
        registered,
      );

      expect(result, isNull);
    });

    test('returns null when there are no registered novels', () {
      final result = resolveNovelId(
        libraryRoot,
        '/library/narou_n1234ab/001.txt',
        const <String>{},
      );

      expect(result, isNull);
    });
  });
}
