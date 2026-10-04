import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/utils/novel_folder_locator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory library;

  setUp(() {
    library = Directory.systemTemp.createTempSync('novel_folder_locator_');
  });

  tearDown(() {
    library.deleteSync(recursive: true);
  });

  Directory mkdir(String relative) =>
      Directory(p.join(library.path, relative))..createSync(recursive: true);

  test('finds a novel directly under the library root', () {
    final novel = mkdir('narou_n1');

    final located = locateNovelFolders(
      libraryRoot: library.path,
      registeredFolderNames: {'narou_n1'},
    );

    expect(located, {'narou_n1': novel.path});
  });

  test('finds a novel nested under organizing folders', () {
    final novel = mkdir(p.join('シリーズ', 'ファンタジー', 'narou_n1234'));

    final located = locateNovelFolders(
      libraryRoot: library.path,
      registeredFolderNames: {'narou_n1234'},
    );

    expect(located['narou_n1234'], novel.path);
  });

  test('a registered name with no folder is absent from the result', () {
    mkdir('narou_n1');

    final located = locateNovelFolders(
      libraryRoot: library.path,
      registeredFolderNames: {'narou_n1', 'narou_gone'},
    );

    expect(located.containsKey('narou_gone'), isFalse);
    expect(located.containsKey('narou_n1'), isTrue);
  });

  test('does not look inside a registered novel folder', () {
    final outer = mkdir('narou_outer');
    mkdir(p.join('narou_outer', 'narou_inner'));

    final located = locateNovelFolders(
      libraryRoot: library.path,
      registeredFolderNames: {'narou_outer', 'narou_inner'},
    );

    expect(located, {'narou_outer': outer.path});
  });

  test('an unregistered folder is not reported', () {
    mkdir('loose_folder');

    final located = locateNovelFolders(
      libraryRoot: library.path,
      registeredFolderNames: const {},
    );

    expect(located, isEmpty);
  });

  test('a missing library root yields nothing instead of throwing', () {
    final located = locateNovelFolders(
      libraryRoot: p.join(library.path, 'absent'),
      registeredFolderNames: {'narou_n1'},
    );

    expect(located, isEmpty);
  });
}
