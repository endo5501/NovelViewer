import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_search/data/search_models.dart';

void main() {
  group('SearchMatch', () {
    test('stores line number and context text', () {
      const match = SearchMatch(lineNumber: 5, contextText: '彼は太郎と呼ばれていた');

      expect(match.lineNumber, 5);
      expect(match.contextText, '彼は太郎と呼ばれていた');
    });
  });

  group('SearchResult', () {
    test('stores file name, file path, and matches', () {
      const matches = [
        SearchMatch(lineNumber: 3, contextText: '太郎は走った'),
        SearchMatch(lineNumber: 10, contextText: '太郎が言った'),
      ];
      const result = SearchResult(
        fileName: '001.txt',
        filePath: '/path/to/001.txt',
        matches: matches,
      );

      expect(result.fileName, '001.txt');
      expect(result.filePath, '/path/to/001.txt');
      expect(result.matches, hasLength(2));
      expect(result.matches[0].lineNumber, 3);
      expect(result.matches[1].lineNumber, 10);
    });

    test('can have empty matches list', () {
      const result = SearchResult(
        fileName: '002.txt',
        filePath: '/path/to/002.txt',
        matches: [],
      );

      expect(result.matches, isEmpty);
    });
  });
}
