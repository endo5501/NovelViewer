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
    final entities = await dir.list().toList();
    final txtFiles = entities
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.txt')
        .toList();

    final results = <SearchResult>[];
    final queryLower = query.toLowerCase();

    for (final file in txtFiles) {
      final content = await file.readAsString();
      final lines = content.split('\n');
      final matches = <SearchMatch>[];

      for (var i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(queryLower)) {
          matches.add(SearchMatch(
            lineNumber: i + 1,
            contextText: lines[i],
          ));
        }
      }

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
