import 'dart:io';

import 'package:novel_viewer/shared/utils/ruby_annotation.dart';
import 'package:path/path.dart' as p;

import 'search_models.dart';

class TextSearchService {
  /// Searches for the Ctrl+F results panel.
  ///
  /// The match decision here runs against the raw line, ruby markup included,
  /// and deliberately differs from [searchWithContext] — see the note there
  /// for why only one of the two strips ruby.
  Future<List<SearchResult>> search(String directoryPath, String query) async {
    if (query.isEmpty) return [];

    final dir = Directory(directoryPath);
    final txtFiles = await dir
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.extension(entity.path).toLowerCase() == '.txt',
        )
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
          .map(
            (entry) => SearchMatch(
              lineNumber: entry.key + 1,
              contextText: entry.value,
            ),
          )
          .toList();

      if (matches.isNotEmpty) {
        results.add(
          SearchResult(
            fileName: p.basename(file.path),
            filePath: file.path,
            matches: matches,
          ),
        );
      }
    }

    return results;
  }

  /// Searches for LLM analysis evidence collection, returning each match with
  /// the lines around it.
  ///
  /// Unlike [search], the match decision runs against the line with its ruby
  /// annotations reduced to their base text. The word being analysed comes
  /// from a reader's selection and therefore carries the *displayed* text, so
  /// a term the author annotated — `紅蓮の剣` stored as
  /// `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣` — is not a contiguous run of the raw
  /// line and would be missed. Authors annotate a term on first use and drop
  /// the ruby later, so what raw matching loses is precisely the page that
  /// introduces and explains the term. Matching the raw line also lets a query
  /// hit the reading inside `<rt>`, which is a false positive.
  ///
  /// [search] is left raw on purpose rather than for lack of the same need:
  /// its results panel prints the raw line and the viewer highlights a ruby
  /// base one segment at a time, so a hit spanning a tag boundary could be
  /// listed but not highlighted. Teaching that path to span boundaries means
  /// changing the highlighting too, which is a larger job than this one.
  ///
  /// Only the decision is stripped. The line number, [SearchMatch.contextText]
  /// and [SearchMatch.extendedContext] stay raw, because ruby in a novel often
  /// carries meaning beyond the reading — a nickname, a second sense, an inner
  /// voice — and the model should see it.
  Future<List<SearchResult>> searchWithContext(
    String directoryPath,
    String query, {
    int contextLines = 2,
  }) async {
    if (query.isEmpty) return [];

    final dir = Directory(directoryPath);
    final txtFiles = await dir
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.extension(entity.path).toLowerCase() == '.txt',
        )
        .cast<File>()
        .toList();

    final results = <SearchResult>[];
    final queryLower = query.toLowerCase();

    for (final file in txtFiles) {
      final content = await file.readAsString();
      final lines = content.split('\n');

      final matches = <SearchMatch>[];
      for (var i = 0; i < lines.length; i++) {
        final base = stripRubyAnnotations(lines[i]).toLowerCase();
        if (base.contains(queryLower)) {
          final start = (i - contextLines).clamp(0, lines.length);
          final end = (i + contextLines + 1).clamp(0, lines.length);
          final contextSlice = lines.sublist(start, end).join('\n');
          matches.add(
            SearchMatch(
              lineNumber: i + 1,
              contextText: lines[i],
              extendedContext: contextSlice,
            ),
          );
        }
      }

      if (matches.isNotEmpty) {
        results.add(
          SearchResult(
            fileName: p.basename(file.path),
            filePath: file.path,
            matches: matches,
          ),
        );
      }
    }

    return results;
  }
}
