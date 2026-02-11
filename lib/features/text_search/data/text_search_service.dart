import 'dart:io';

import 'package:path/path.dart' as p;

import 'search_models.dart';

class TextSearchService {
  Future<List<SearchResult>> search(
    String directoryPath,
    String query,
  ) async {
    if (query.isEmpty) return [];

    final dir = Directory(directoryPath);
    final txtFiles = await dir
        .list()
        .where((entity) =>
            entity is File &&
            p.extension(entity.path).toLowerCase() == '.txt')
        .cast<File>()
        .toList();

    final results = <SearchResult>[];
    final queryLower = query.toLowerCase();

    for (final file in txtFiles) {
      final content = await file.readAsString();
      final lines = content.split('\n');

      final matches = lines
          .asMap()
          .entries
          .where((entry) => entry.value.toLowerCase().contains(queryLower))
          .map((entry) => SearchMatch(
                lineNumber: entry.key + 1,
                contextText: entry.value,
              ))
          .toList();

      if (matches.isNotEmpty) {
        results.add(SearchResult(
          fileName: p.basename(file.path),
          filePath: file.path,
          matches: matches,
        ));
      }
    }

    return results;
  }
}
