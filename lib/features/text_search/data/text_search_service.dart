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

  Future<List<SearchResult>> searchWithContext(
    String directoryPath,
    String query, {
    int contextLines = 2,
  }) async {
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

      final matches = <SearchMatch>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(queryLower)) {
          final start = (i - contextLines).clamp(0, lines.length);
          final end = (i + contextLines + 1).clamp(0, lines.length);
          final contextSlice = lines.sublist(start, end).join('\n');
          matches.add(SearchMatch(
            lineNumber: i + 1,
            contextText: lines[i],
            extendedContext: contextSlice,
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
