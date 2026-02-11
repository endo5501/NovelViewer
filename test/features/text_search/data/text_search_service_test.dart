import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_search/data/text_search_service.dart';

void main() {
  late TextSearchService service;
  late Directory tempDir;

  setUp(() async {
    service = TextSearchService();
    tempDir = await Directory.systemTemp.createTemp('search_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createFile(String name, String content) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(content);
  }

  group('TextSearchService', () {
    test('finds matches in multiple files', () async {
      await createFile('001.txt', '太郎は走った\n次郎は歩いた');
      await createFile('002.txt', '太郎が言った\n花子が笑った');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, hasLength(2));

      final fileNames = results.map((r) => r.fileName).toSet();
      expect(fileNames, containsAll(['001.txt', '002.txt']));

      for (final result in results) {
        expect(result.matches, isNotEmpty);
        for (final match in result.matches) {
          expect(match.contextText, contains('太郎'));
        }
      }
    });

    test('returns empty list when no matches found', () async {
      await createFile('001.txt', '花子は走った');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, isEmpty);
    });

    test('search is case-insensitive for ASCII', () async {
      await createFile('001.txt', 'Hello World\nGoodbye');

      final results = await service.search(tempDir.path, 'hello');

      expect(results, hasLength(1));
      expect(results[0].matches, hasLength(1));
      expect(results[0].matches[0].contextText, contains('Hello'));
    });

    test('includes line number in match', () async {
      await createFile('001.txt', '1行目\n2行目に太郎\n3行目');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, hasLength(1));
      expect(results[0].matches, hasLength(1));
      expect(results[0].matches[0].lineNumber, 2);
    });

    test('includes context text for each match', () async {
      await createFile('001.txt', '前の文\n太郎が走った\n後の文');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, hasLength(1));
      expect(results[0].matches[0].contextText, '太郎が走った');
    });

    test('finds multiple matches in same file', () async {
      await createFile('001.txt', '太郎が走った\n次郎が歩いた\n太郎が言った');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, hasLength(1));
      expect(results[0].matches, hasLength(2));
      expect(results[0].matches[0].lineNumber, 1);
      expect(results[0].matches[1].lineNumber, 3);
    });

    test('only searches .txt files', () async {
      await createFile('001.txt', '太郎が走った');
      await createFile('002.md', '太郎が歩いた');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, hasLength(1));
      expect(results[0].fileName, '001.txt');
    });

    test('returns results with correct file path', () async {
      await createFile('001.txt', '太郎が走った');

      final results = await service.search(tempDir.path, '太郎');

      expect(results, hasLength(1));
      expect(results[0].filePath, '${tempDir.path}/001.txt');
    });
  });
}
